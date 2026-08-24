import Foundation

/// Simplified spaced repetition scheduler.
///
/// Interval strategy (in seconds):
///   Again   → stability * 0.25, minimum 60s
///   Hard    → stability * 1.2, minimum 300s
///   Good    → stability * 2.5
///   Easy    → stability * 4.0
///
/// First review (stability == 0):
///   Again   → 60s
///   Hard    → 5 minutes
///   Good    → 20 minutes
///   Easy    → 1 day
///
/// Difficulty increases as forgetCount increases, reducing intervals for problematic words.
public final class SimpleSpacedRepetitionScheduler: ReviewScheduler {

    public init() {}

    func nextReviewInterval(for state: LearningState, rating: Rating) -> Double {
        let difficultyFactor = 1.0 - (state.difficulty * 0.1)
        let baseInterval: Double

        switch rating {
        case .again:
            baseInterval = max(state.stability * 0.25, 60.0)
        case .hard:
            baseInterval = max(state.stability * 1.2, 180.0)
        case .good:
            baseInterval = state.stability * 2.5
        case .easy:
            baseInterval = state.stability * 4.0
        }

        // First-time reviews use fixed base intervals
        let interval: Double
        if state.stability == 0 {
            switch rating {
            case .again: interval = 60.0
            case .hard: interval = 300.0
            case .good: interval = 1200.0  // 20 minutes
            case .easy: interval = 86400.0 // 1 day
            }
        } else {
            interval = max(baseInterval * difficultyFactor, 60.0)
        }

        return interval
    }

    func updateState(_ state: inout LearningState, rating: Rating) {
        state.reviewCount += 1

        switch rating {
        case .again:
            state.forgetCount += 1
            state.stability = min(state.stability * 0.5, 10.0)
            state.difficulty = min(state.difficulty + 0.3, 10.0)
        case .hard:
            state.difficulty = min(state.difficulty + 0.1, 10.0)
            state.stability = max(state.stability * 0.9, 1.0)
        case .good:
            state.stability *= 1.5
            state.difficulty = max(state.difficulty - 0.05, 0.0)
        case .easy:
            state.stability *= 2.0
            state.difficulty = max(state.difficulty - 0.2, 0.0)
        }

        let interval = nextReviewInterval(for: state, rating: rating)
        state.nextReviewAt = Date().addingTimeInterval(interval)
        state.lastReviewedAt = Date()
        state.lastRating = rating.rawValue

        state.state = computeState(for: state)
    }

    func computeState(for state: LearningState) -> String {
        if state.reviewCount == 0 { return "New" }

        let forgetRatio = Double(state.forgetCount) / Double(state.reviewCount)

        if forgetRatio >= 0.4 && state.reviewCount >= 5 {
            return "Difficult"
        }

        if state.stability >= 21600 && state.difficulty < 2.0 && state.reviewCount >= 8 {
            return "Mastered"
        }

        if state.nextReviewAt != nil && state.nextReviewAt! > Date() {
            return "Review"
        }

        return "Learning"
    }
}
