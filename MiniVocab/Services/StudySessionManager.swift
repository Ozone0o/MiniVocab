import Foundation
import SwiftData

/// Manages a single study session using Round/Group architecture.
@MainActor
final class StudySessionManager {
    let persistence: PersistenceController
    private let scheduler: ReviewScheduler
    private let exampleDatabase: ExampleDatabase?

    // MARK: - Round configuration (captured at start)

    private var currentRoundSize: Int = 20
    private var currentGroupRoundCount: Int = 5

    // MARK: - Round state

    private var currentRoundQueue: [Word] = []
    private var completedRoundsInGroup: Int = 0
    private var isGroupReviewing: Bool = false
    private var groupReviewQueue: [Word] = []
    private var weaknessScores: [String: Int] = [:]
    private var currentRoundTotal: Int = 0
    private var roundPassedWords: Set<String> = []

    // MARK: - Order mode

    private var shuffledNewWordIds: [String] = []
    private var shuffledPosition: Int = 0
    private var activeBook: WordBook?

    // MARK: - Overdue tracking

    private var overdueQueue: [Word] = []

    // MARK: - Wordbook order tracking

    private var nextNewWordPosition: Int = 0
    private var bookWordOrder: [String] = []
    private var introducedWordIds: Set<String> = []

    // MARK: - Current word (for diagnostics)

    var currentWord: Word?

    init(persistence: PersistenceController, scheduler: ReviewScheduler) {
        self.persistence = persistence
        self.scheduler = scheduler
        self.exampleDatabase = ExampleDatabase.load()
        loadConfiguration()
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        currentRoundSize = SettingsStore.shared.wordsPerRound
        if currentRoundSize < 1 { currentRoundSize = 1 }
        if currentRoundSize > 100 { currentRoundSize = 100 }
        currentGroupRoundCount = SettingsStore.shared.roundsPerGroup
        if currentGroupRoundCount < 1 { currentGroupRoundCount = 1 }
        if currentGroupRoundCount > 20 { currentGroupRoundCount = 20 }
    }

    func reloadConfiguration() {
        var newRoundSize = SettingsStore.shared.wordsPerRound
        if newRoundSize < 1 { newRoundSize = 1 }
        if newRoundSize > 100 { newRoundSize = 100 }
        var newGroupCount = SettingsStore.shared.roundsPerGroup
        if newGroupCount < 1 { newGroupCount = 1 }
        if newGroupCount > 20 { newGroupCount = 20 }

        if !isGroupReviewing && currentRoundQueue.isEmpty && groupReviewQueue.isEmpty {
            currentRoundSize = newRoundSize
            currentGroupRoundCount = newGroupCount
        }
    }

    // MARK: - Start / Restore Session

    /// Start a session with a specific book. Called by WordBookService after enabling the book.
    func startSession(for book: WordBook, wordIds: [String]) {
        activeBook = book
        currentRoundQueue = []
        completedRoundsInGroup = 0
        isGroupReviewing = false
        groupReviewQueue = []
        weaknessScores = [:]
        roundPassedWords = .init()
        shuffledNewWordIds = []
        shuffledPosition = 0
        overdueQueue = []
        nextNewWordPosition = 0
        introducedWordIds = .init()

        bookWordOrder = wordIds.isEmpty ? (book.words.map(\.id)) : wordIds
        loadConfiguration()
    }

    /// Restore the active book on app launch. Finds the enabled book and starts a session.
    func restoreActiveBook() throws {
        let books = try persistence.fetchAllWordBooks()
        if let enabledBook = books.first(where: { $0.isEnabled }) {
            let wordIds = enabledBook.words.map(\.id)
            startSession(for: enabledBook, wordIds: wordIds)
        }
    }

    // MARK: - Next Word

    func nextWord() throws -> Word? {
        guard activeBook != nil else {
            currentWord = nil
            return nil
        }

        // 1. Try group review queue
        if let word = nextFromGroupReview() { return word }

        // 2. Try current round queue
        if let word = nextFromCurrentRound() { return word }

        // 3. Check if current round is complete
        if checkRoundCompletion() {
            if let word = nextFromGroupReview() { return word }
            if !currentRoundQueue.isEmpty { return nextFromCurrentRound() }
        }

        // 4. Try overdue long-term reviews
        if let word = try? nextFromOverdue() { return word }

        // 5. Try current round queue again (for re-queued words)
        if let word = nextFromCurrentRound() { return word }

        // 6. Build a new round
        if let word = try buildNewRound() { return word }

        // 7. No words available
        currentWord = nil
        return nil
    }

    // MARK: - Unified Preparation (single entry point for all word display)

    /// Every Word must pass through this before reaching FloatingWordView.
    /// Handles example enrichment (from local SQLite if missing) and sets currentWord.
    private func prepareForDisplay(_ word: Word) throws -> Word {
        let hasExample = !(word.example?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ?? true)

        if !hasExample,
           let db = exampleDatabase,
           let example = db.lookup(for: word.text) {
            word.example = example
            do {
                try persistence.save()
            } catch {
                print("[MiniVocab] Failed to save example for word '\(word.text)': \(error)")
            }
        }

        currentWord = word
        return word
    }

    // MARK: - Queue Readers (all go through prepareForDisplay)

    private func nextFromGroupReview() -> Word? {
        guard isGroupReviewing, !groupReviewQueue.isEmpty else { return nil }
        let word = groupReviewQueue.removeFirst()
        return try? prepareForDisplay(word)
    }

    private func nextFromCurrentRound() -> Word? {
        guard !currentRoundQueue.isEmpty else { return nil }
        let word = currentRoundQueue.removeFirst()
        return try? prepareForDisplay(word)
    }

    private func nextFromOverdue() throws -> Word? {
        if overdueQueue.isEmpty {
            overdueQueue = try fetchOverdueWords()
        }

        guard !overdueQueue.isEmpty else { return nil }

        let word = overdueQueue.removeFirst()
        return try prepareForDisplay(word)
    }

    private func fetchOverdueWords() throws -> [Word] {
        let states = try persistence.modelContainer.mainContext.fetch(FetchDescriptor<LearningState>())
        let now = Date()
        let overdueIds = states
            .filter { $0.nextReviewAt != nil && $0.nextReviewAt! <= now && $0.state != "New" }
            .map(\.wordId)

        var words: [Word] = []
        for id in overdueIds {
            if let word = try? persistence.fetchWord(id: id),
               bookWordOrder.contains(id) {
                words.append(word)
            }
        }
        return words
    }

    // MARK: - Build New Round

    private func buildNewRound() throws -> Word? {
        if !currentRoundQueue.isEmpty {
            return nextFromCurrentRound()
        }

        if completedRoundsInGroup >= currentGroupRoundCount {
            startGroupReview()
            return nextFromGroupReview()
        }

        guard activeBook != nil else { return nil }

        var newWords: [Word] = []

        if SettingsStore.shared.wordOrderMode == "random" && shuffledNewWordIds.isEmpty {
            shuffledNewWordIds = bookWordOrder.shuffled()
            shuffledPosition = 0
        }

        if SettingsStore.shared.wordOrderMode == "random" {
            let count = min(currentRoundSize, shuffledNewWordIds.count - shuffledPosition)
            for i in 0..<count {
                let idx = shuffledPosition + i
                if idx < shuffledNewWordIds.count,
                   let word = try? persistence.fetchWord(id: shuffledNewWordIds[idx]) {
                    newWords.append(word)
                }
            }
            shuffledPosition += count
        } else {
            let start = nextNewWordPosition
            let end = min(start + currentRoundSize, bookWordOrder.count)
            for i in start..<end {
                let id = bookWordOrder[i]
                if let word = try? persistence.fetchWord(id: id) {
                    newWords.append(word)
                }
            }
            nextNewWordPosition = end
        }

        guard !newWords.isEmpty else {
            if completedRoundsInGroup > 0 {
                startGroupReview()
                return nextFromGroupReview()
            }
            currentWord = nil
            return nil
        }

        currentRoundQueue = newWords
        currentRoundTotal = newWords.count
        roundPassedWords = .init()
        introducedWordIds.formUnion(newWords.map(\.id))

        return nextFromCurrentRound()
    }

    // MARK: - Record Rating

    func recordRating(word: Word, rating: Rating) throws {
        var state = try persistence.fetchOrCreateLearningState(wordId: word.id)

        let previousInterval: Double
        if let lastReviewed = state.lastReviewedAt, let nextRev = state.nextReviewAt {
            previousInterval = nextRev.timeIntervalSince(lastReviewed)
        } else {
            previousInterval = 0
        }

        let interval = scheduler.apply(rating, to: &state)

        let reviewRecord = ReviewRecord(
            wordId: word.id,
            rating: rating.rawValue,
            previousInterval: previousInterval,
            nextInterval: interval
        )
        persistence.modelContainer.mainContext.insert(reviewRecord)

        try persistence.save()

        switch rating {
        case .again: handleAgain(word: word)
        case .hard: handleHard(word: word)
        case .good: handleGood(word: word)
        case .easy: handleEasy(word: word)
        }
    }

    // MARK: - Rating Handlers

    private func handleAgain(word: Word) {
        weaknessScores[word.id, default: 0] += 3
        roundPassedWords.remove(word.id)

        let insertIndex = min(2, currentRoundQueue.count)
        currentRoundQueue.insert(word, at: insertIndex)
    }

    private func handleHard(word: Word) {
        weaknessScores[word.id, default: 0] += 1
        roundPassedWords.remove(word.id)

        currentRoundQueue.append(word)
    }

    private func handleGood(word: Word) {
        roundPassedWords.insert(word.id)
    }

    private func handleEasy(word: Word) {
        roundPassedWords.insert(word.id)
    }

    // MARK: - Round Completion Check

    func checkRoundCompletion() -> Bool {
        guard currentRoundTotal > 0, currentRoundQueue.isEmpty else { return false }

        if roundPassedWords.count >= currentRoundTotal {
            completedRoundsInGroup += 1

            for id in weaknessScores.keys where roundPassedWords.contains(id) {
                if let word = try? persistence.fetchWord(id: id) {
                    if !groupReviewQueue.contains(where: { $0.id == word.id }) {
                        groupReviewQueue.append(word)
                    }
                }
            }

            currentRoundQueue = []
            currentRoundTotal = 0
            roundPassedWords = .init()

            return true
        }

        return false
    }

    // MARK: - Group Review

    private func startGroupReview() {
        isGroupReviewing = true

        groupReviewQueue.sort { lhs, rhs in
            (weaknessScores[lhs.id] ?? 0) > (weaknessScores[rhs.id] ?? 0)
        }
    }

    // MARK: - Switch/Reset

    func clearSession() {
        activeBook = nil
        currentRoundQueue = []
        completedRoundsInGroup = 0
        isGroupReviewing = false
        groupReviewQueue = []
        weaknessScores = [:]
        roundPassedWords = .init()
        shuffledNewWordIds = []
        shuffledPosition = 0
        overdueQueue = []
        nextNewWordPosition = 0
        bookWordOrder = []
        introducedWordIds = .init()
    }
}
