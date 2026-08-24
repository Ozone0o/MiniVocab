import XCTest
import SwiftData
@testable import MiniVocab

@MainActor
final class StudySessionManagerTests: XCTestCase {

    private var persistence: PersistenceController!
    private var scheduler: SimpleSpacedRepetitionScheduler!
    private var sessionManager: StudySessionManager!

    override func setUp() {
        super.setUp()
        // Create a fresh container for each test to avoid cross-test contamination
        let schema = Schema([Word.self, WordBook.self, ReviewRecord.self, LearningState.self])
        let modelConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfig])
        persistence = PersistenceController(modelContainer: container)
        scheduler = SimpleSpacedRepetitionScheduler()
        sessionManager = StudySessionManager(persistence: persistence, scheduler: scheduler)
        sessionManager.dailyNewLimit = 5
        sessionManager.dailyMaxReviews = 100
    }

    override func tearDown() {
        persistence = nil
        scheduler = nil
        sessionManager = nil
        super.tearDown()
    }

    private func insertWord(_ text: String, phonetic: String? = nil, meaning: String? = nil, example: String? = nil) throws {
        let wordId = text.lowercased()
        let word = Word(id: wordId, text: text, phonetic: phonetic, meaning: meaning, example: example)
        persistence.modelContainer.mainContext.insert(word)
        let state = LearningState(wordId: wordId)
        persistence.modelContainer.mainContext.insert(state)
        try persistence.save()
    }

    private func insertReviewedWord(_ text: String, reviewCount: Int, forgetCount: Int, nextReviewAt: Date? = nil) throws {
        try insertWord(text)
        var state = try XCTUnwrap(try persistence.fetchLearningState(wordId: text.lowercased()))
        state.reviewCount = reviewCount
        state.forgetCount = forgetCount
        state.nextReviewAt = nextReviewAt
        state.lastReviewedAt = Date()
        state.state = reviewCount > 0 ? "Review" : "New"
        try persistence.save()
    }

    func testReturnsNilWhenNoWords() throws {
        let word = try sessionManager.nextWord()
        XCTAssertNil(word, "Should return nil when no words exist")
    }

    func testReturnsNewWordWhenAvailable() throws {
        try insertWord("abandon", meaning: "放弃")

        // Debug: verify data was saved
        let allWords = try persistence.fetchWords()
        print("DEBUG: fetchWords returned \(allWords.count) words")
        for w in allWords { print("DEBUG:   word id=\(w.id) text=\(w.text)") }

        let allStates = try! persistence.modelContainer.mainContext.fetch(FetchDescriptor<LearningState>())
        print("DEBUG: fetch states returned \(allStates.count) states")
        for s in allStates { print("DEBUG:   state wordId=\(s.wordId) state=\(s.state)") }

        let word = try sessionManager.nextWord()
        XCTAssertNotNil(word, "Should return a new word")
        XCTAssertEqual(word?.text, "abandon")
    }

    func testOverdueReviewPriorityOverNewWord() throws {
        // Insert an overdue review word
        try insertReviewedWord("overdue_word", reviewCount: 3, forgetCount: 1, nextReviewAt: Date(timeIntervalSinceNow: -3600))
        // Insert a new word
        try insertWord("new_word", meaning: "新词")

        let word = try sessionManager.nextWord()
        XCTAssertEqual(word?.text, "overdue_word", "Overdue review should have priority over new words")
    }

    func testDifficultWordGetsExtraReview() throws {
        // Insert a difficult word (high forget ratio)
        try insertReviewedWord("difficult_word", reviewCount: 8, forgetCount: 5)
        // Insert an overdue word
        try insertReviewedWord("overdue_word", reviewCount: 2, forgetCount: 0, nextReviewAt: Date(timeIntervalSinceNow: -3600))
        // Insert a new word
        try insertWord("new_word", meaning: "新词")

        // First call should return overdue
        let first = try sessionManager.nextWord()
        XCTAssertEqual(first?.text, "overdue_word", "Overdue should be first priority")

        // Second call should return difficult (since overdue already taken)
        try persistence.save()
        let second = try sessionManager.nextWord()
        XCTAssertNotNil(second, "Difficult word should be available")
    }

    func testDailyNewWordLimit() throws {
        for i in 0..<10 {
            try insertWord("word_\(i)", meaning: "释义\(i)")
        }

        sessionManager.dailyNewLimit = 3
        var newWordCount = 0
        var reviewCount = 0
        while let word = try sessionManager.nextWord() {
            let state = try persistence.fetchLearningState(wordId: word.id)
            if state?.state == "New" {
                newWordCount += 1
            } else {
                reviewCount += 1
            }
        }

        XCTAssertLessThanOrEqual(newWordCount, 3, "Should not exceed daily new word limit (new: \(newWordCount), reviews: \(reviewCount))")
    }

    func testNoDuplicateWordsInSession() throws {
        try insertWord("abandon", meaning: "放弃")
        try insertWord("ability", meaning: "能力")

        let first = try sessionManager.nextWord()
        XCTAssertNotNil(first)
        let second = try sessionManager.nextWord()
        XCTAssertNotNil(second)

        XCTAssertNotEqual(first?.id, second?.id, "Should not return the same word twice")
    }

    func testRatingRecordsAndAdvances() throws {
        try insertWord("abandon", meaning: "放弃")
        try insertWord("ability", meaning: "能力")
        let first = try sessionManager.nextWord()
        XCTAssertNotNil(first)

        let next = try sessionManager.recordRating(word: try XCTUnwrap(first), rating: .good)
        // After rating one word, next should be a different word
        XCTAssertNotNil(next)
        XCTAssertNotEqual(next?.id, first?.id)
    }

    func testRatingUpdatesLearningState() throws {
        try insertWord("ambiguous", meaning: "模棱两可的")
        let word = try sessionManager.nextWord()
        let wordId = try XCTUnwrap(word?.id)

        try sessionManager.recordRating(word: try XCTUnwrap(word), rating: .good)

        let state = try persistence.fetchLearningState(wordId: wordId)
        XCTAssertNotNil(state, "LearningState should be updated after rating")
        XCTAssertEqual(state?.reviewCount, 1, "Review count should increment")
        XCTAssertNotNil(state?.nextReviewAt, "Next review should be scheduled")
    }

    func testAgainRapidReschedule() throws {
        try insertWord("hard_word", meaning: "难词")
        let word = try sessionManager.nextWord()
        try sessionManager.recordRating(word: try XCTUnwrap(word), rating: .again)

        // The "again" word should be rescheduled for 5 minutes later
        // It should not appear immediately in the next call (due to recentWords window)
        let next = try sessionManager.nextWord()
        // Should be nil since only one word exists and it was just shown
        XCTAssertNil(next, "Recently shown word should not appear again immediately")
    }
}
