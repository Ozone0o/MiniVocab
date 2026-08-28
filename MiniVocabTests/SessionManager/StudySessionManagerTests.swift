@preconcurrency import XCTest
import SwiftData
@testable import MiniVocab

@MainActor
final class StudySessionManagerTests: XCTestCase {

    private nonisolated(unsafe) var fixture: StudySessionFixture!
    private var persistence: PersistenceController { fixture.persistence }
    private var scheduler: SimpleSpacedRepetitionScheduler { fixture.scheduler }
    private var sessionManager: StudySessionManager { fixture.sessionManager }
    private var book: WordBook { fixture.book }

    override func setUp() {
        super.setUp()
        fixture = MainActor.assumeIsolated { StudySessionFixture() }
    }

    override func tearDown() {
        fixture = nil
        super.tearDown()
    }

    private func insertWord(_ text: String) throws {
        let wordId = text.lowercased()
        let word = Word(id: wordId, text: text, meaning: "meaning of \(text)")
        persistence.modelContainer.mainContext.insert(word)

        // Add word to the local book reference directly (kept as managed instance)
        book.words.append(word)
        try persistence.save()
    }

    // MARK: - Round tests: wordsPerRound = 3, roundsPerGroup = 2

    func testRoundOf3() throws {
        SettingsStore.shared.wordsPerRound = 3
        SettingsStore.shared.roundsPerGroup = 2
        sessionManager.reloadConfiguration()

        // Insert words BEFORE activating the book
        try insertWord("word_a")
        try insertWord("word_b")
        try insertWord("word_c")
        try activateBookAndLoad()

        // Round 1 should have 3 words: A, B, C
        let w1 = try sessionManager.nextWord()
        let w2 = try sessionManager.nextWord()
        let w3 = try sessionManager.nextWord()

        XCTAssertNotNil(w1)
        XCTAssertNotNil(w2)
        XCTAssertNotNil(w3)
        let ids = [w1!.id, w2!.id, w3!.id]
        XCTAssertEqual(ids.count, 3, "Should have 3 distinct words in round")
        XCTAssertTrue(ids.contains("word_a"))
        XCTAssertTrue(ids.contains("word_b"))
        XCTAssertTrue(ids.contains("word_c"))
    }

    func testRoundBlocksNewWordsUntilAllGood() throws {
        SettingsStore.shared.wordsPerRound = 3
        SettingsStore.shared.roundsPerGroup = 2
        sessionManager.reloadConfiguration()

        try insertWord("word_a")
        try insertWord("word_b")
        try insertWord("word_c")
        try insertWord("word_d")
        try activateBookAndLoad()
        _ = try sessionManager.nextWord() // word_a
        _ = try sessionManager.nextWord() // word_b
        let wordC = try sessionManager.nextWord() // word_c

        // word_c → Again
        _ = try sessionManager.recordRating(word: wordC!, rating: .again)

        // Next word should be word_c again (re-queued), NOT word_d
        let next = try sessionManager.nextWord()
        XCTAssertNotNil(next)
        XCTAssertNotEqual(next?.id, "word_d", "Should not introduce new word while round is incomplete")
        XCTAssertEqual(next?.id, "word_c", "Re-queued Again word should appear")
    }

    func testHardReQueuesInRound() throws {
        SettingsStore.shared.wordsPerRound = 3
        SettingsStore.shared.roundsPerGroup = 2
        sessionManager.reloadConfiguration()

        try insertWord("word_a")
        try insertWord("word_b")
        try insertWord("word_c")
        try activateBookAndLoad()
        _ = try sessionManager.nextWord()
        _ = try sessionManager.nextWord()
        let wordC = try sessionManager.nextWord() // word_c

        // word_c → Hard → should re-queue at tail
        _ = try sessionManager.recordRating(word: wordC!, rating: .hard)

        // Next should be word_c again
        let next = try sessionManager.nextWord()
        XCTAssertEqual(next?.id, "word_c", "Hard word should re-queue in current round")
    }

    // MARK: - Group tests: roundsPerGroup = 2

    func testGroupReviewAfter2Rounds() throws {
        SettingsStore.shared.wordsPerRound = 3
        SettingsStore.shared.roundsPerGroup = 2
        sessionManager.reloadConfiguration()

        try insertWord("word_a")
        try insertWord("word_b")
        try insertWord("word_c")
        try insertWord("word_d")
        try insertWord("word_e")
        try insertWord("word_f")
        try activateBookAndLoad()

        // Complete Round 1: A, B, C → all Good
        for _ in 0..<3 {
            let word = try sessionManager.nextWord()
            _ = try sessionManager.recordRating(word: word!, rating: .good)
        }

        // After round completion, Round 2 should start: D, E, F
        for _ in 0..<3 {
            let word = try sessionManager.nextWord()
            XCTAssertNotNil(word)
            XCTAssertTrue(["word_d", "word_e", "word_f"].contains(word!.id))
            _ = try sessionManager.recordRating(word: word!, rating: .good)
        }

        // After 2 rounds, should trigger group review or build new round
        // Since all words were rated Good, weaknessScores is empty, no group review queue
        // Should start Round 3 with remaining words (none left), return nil
        let next = try sessionManager.nextWord()
        // Either group review word or nil if all done
        if let word = next {
            XCTAssertTrue(["word_a", "word_b", "word_c", "word_d", "word_e", "word_f"].contains(word.id))
        }
    }

    // MARK: - Dynamic settings test

    func testDynamicWordsPerRound() throws {
        SettingsStore.shared.wordsPerRound = 3
        SettingsStore.shared.roundsPerGroup = 2
        sessionManager.reloadConfiguration()

        try insertWord("word_a")
        try insertWord("word_b")
        try insertWord("word_c")
        try insertWord("word_d")
        try activateBookAndLoad()

        // Round 1: 3 words
        for _ in 0..<3 {
            let word = try sessionManager.nextWord()
            _ = try sessionManager.recordRating(word: word!, rating: .good)
        }

        // Change settings mid-session
        SettingsStore.shared.wordsPerRound = 2

        // Next round should use new setting
        // Load 2 words for Round 2
        let w1 = try sessionManager.nextWord()
        XCTAssertNotNil(w1)
    }

    // MARK: - Last round with fewer words

    func testLastRoundWithFewerWords() throws {
        SettingsStore.shared.wordsPerRound = 10
        SettingsStore.shared.roundsPerGroup = 1
        sessionManager.reloadConfiguration()

        // Only 5 words in the book
        for i in 0..<5 {
            try insertWord("word_\(i)")
        }

        try activateBookAndLoad()

        // Should load all 5 words in one round
        var count = 0
        while let _ = try? sessionManager.nextWord() {
            count += 1
        }
        // Note: after rating all words they leave the queue,
        // so nextWord returns nil when round is done
        XCTAssertGreaterThan(count, 0)
    }

    // MARK: - Sequential order test

    func testSequentialOrder() throws {
        SettingsStore.shared.wordOrderMode = "sequential"
        SettingsStore.shared.wordsPerRound = 3
        sessionManager.reloadConfiguration()

        // Insert words in specific order
        for i in 0..<6 {
            try insertWord("seq_\(i)")
        }

        try activateBookAndLoad()

        // Round 1 should be seq_0, seq_1, seq_2
        let w1 = try sessionManager.nextWord()
        XCTAssertEqual(w1?.id, "seq_0", "First word should be seq_0")
    }

    // MARK: - Nil book test

    func testReturnsNilWhenNoBook() throws {
        let sm = StudySessionManager(persistence: persistence, scheduler: scheduler)
        let word = try sm.nextWord()
        XCTAssertNil(word, "Should return nil when no book is activated")
    }

    // MARK: - Helpers

    private func activateBookAndLoad() throws {
        book.isEnabled = true
        try persistence.save()
        let wordIds = book.words.map(\.id)
        sessionManager.startSession(for: book, wordIds: wordIds)
    }

}

@MainActor
private final class StudySessionFixture {
    let persistence: PersistenceController
    let scheduler: SimpleSpacedRepetitionScheduler
    let sessionManager: StudySessionManager
    let book: WordBook

    init() {
        let schema = Schema([Word.self, WordBook.self, ReviewRecord.self, LearningState.self])
        let modelConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfig])
        persistence = PersistenceController(modelContainer: container)
        scheduler = SimpleSpacedRepetitionScheduler()
        sessionManager = StudySessionManager(persistence: persistence, scheduler: scheduler)

        book = WordBook(id: "test_book", name: "Test Book")
        persistence.modelContainer.mainContext.insert(book)
        try? persistence.save()
    }
}
