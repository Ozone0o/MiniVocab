import Foundation
import SwiftData

/// Manages a single study session — picks the next word based on priority
@MainActor
final class StudySessionManager {
    let persistence: PersistenceController
    private let scheduler: ReviewScheduler
    private var recentWords: [String] = []  // sliding window of recently shown word ids
    private let recentWindowCount = 10

    init(persistence: PersistenceController, scheduler: ReviewScheduler) {
        self.persistence = persistence
        self.scheduler = scheduler
    }

    /// Daily limits (can be overridden by AppSettings)
    var dailyNewLimit: Int = 20
    var dailyMaxReviews: Int = 100

    /// The current word being shown, or nil if no words available
    var currentWord: Word?

    // MARK: - Next Word

    func nextWord() throws -> Word? {
        // Clear completed daily counters if new day
        try cleanupDailyReviewCount()

        let overdue = try fetchOverdueWords()
        let difficult = try fetchDifficultWords(overdueIds: Set(overdue.map(\.id)))
        let newWords = try fetchNewWords()

        let pool = buildPool(overdue: overdue, difficult: difficult, newWords: newWords)

        guard let word = pool.first else {
            currentWord = nil
            return nil
        }

        currentWord = word
        recentWords.append(word.id)
        if recentWords.count > recentWindowCount {
            recentWords.removeFirst()
        }
        return word
    }

    /// Record a rating and advance to next word
    func recordRating(word: Word, rating: Rating) throws -> Word? {
        var state = try persistence.fetchOrCreateLearningState(wordId: word.id)
        scheduler.updateState(&state, rating: rating)
        try persistence.save()

        // If rated "again", schedule it for quick re-insertion
        if rating == .again {
            state.nextReviewAt = Date().addingTimeInterval(300) // 5 minutes
        }

        return try nextWord()
    }

    // MARK: - Internal

    private func fetchOverdueWords() throws -> [Word] {
        var words = try persistence.fetchOverdueReviews()
        // Filter out words shown recently
        words.removeAll { recentWords.contains($0.id) }
        return words
    }

    private func fetchDifficultWords(overdueIds: Set<String>) throws -> [Word] {
        var words = try persistence.fetchDifficultWords()
        words.removeAll { recentWords.contains($0.id) || overdueIds.contains($0.id) }
        // Prioritize higher forget ratio
        words.sort { lhs, rhs in
            let lhsState = try? persistence.fetchLearningState(wordId: lhs.id)
            let rhsState = try? persistence.fetchLearningState(wordId: rhs.id)
            let lhsRatio = lhsState.map { Double($0.forgetCount) / max(Double($0.reviewCount), 1) } ?? 0
            let rhsRatio = rhsState.map { Double($0.forgetCount) / max(Double($0.reviewCount), 1) } ?? 0
            return lhsRatio > rhsRatio
        }
        return Array(words.prefix(5))
    }

    private func fetchNewWords() throws -> [Word] {
        // Count already shown new words today
        let shownToday = try persistence.fetchReviewedWordIds()
        let allNew = try persistence.fetchNewWords(limit: dailyNewLimit + shownToday.count)
        let remaining = dailyNewLimit - shownToday.count
        let filtered = allNew.filter { !recentWords.contains($0.id) && !shownToday.contains($0.id) }
        return Array(filtered.prefix(max(remaining, 0)))
    }

    private func buildPool(overdue: [Word], difficult: [Word], newWords: [Word]) -> [Word] {
        var pool: [Word] = []
        var seen = Set<String>()

        for word in overdue + difficult + newWords {
            if seen.insert(word.id).inserted {
                pool.append(word)
            }
        }

        return pool
    }

    private func cleanupDailyReviewCount() throws {
        // Simple day-check: if lastReviewedAt is from a previous day, reset state
        // In production, store lastResetDate in AppSettings
        let calendar = Calendar.current
        guard let state = try persistence.fetchLearningState(wordId: "") else { return }
        _ = state // placeholder; real implementation stores AppSettings
    }
}
