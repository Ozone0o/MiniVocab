import Foundation

/// Simplified spaced repetition scheduler.
public final class SimpleSpacedRepetitionScheduler: ReviewScheduler {

    public init() {}

    func apply(_ rating: Rating, to state: inout LearningState) -> Double {
        state.reviewCount += 1

        // First review: set initial stability
        let isFirst = state.stability == 0.0
        if isFirst {
            switch rating {
            case .again: state.stability = 0.0
            case .hard: state.stability = 1.0
            case .good: state.stability = 2.5
            case .easy: state.stability = 4.0
            }
        } else {
            switch rating {
            case .again:
                state.stability = min(state.stability * 0.5, 10.0)
            case .hard:
                state.stability = max(state.stability * 0.9, 1.0)
            case .good:
                state.stability *= 1.5
            case .easy:
                state.stability *= 2.0
            }
        }

        switch rating {
        case .again:
            state.forgetCount += 1
            state.difficulty = min(state.difficulty + 1.0, 10.0)
        case .hard:
            state.difficulty = min(state.difficulty + 0.25, 10.0)
        case .good:
            state.difficulty = max(state.difficulty - 0.10, 0.0)
        case .easy:
            state.difficulty = max(state.difficulty - 0.30, 0.0)
        }

        let interval = calculateInterval(stability: state.stability, difficulty: state.difficulty, isFirst: isFirst, rating: rating)
        state.nextReviewAt = Date().addingTimeInterval(interval)
        state.lastReviewedAt = Date()
        state.lastRating = rating.rawValue
        state.state = computeState(for: state)

        return interval
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

    // MARK: - Interval Calculation

    private func calculateInterval(stability: Double, difficulty: Double, isFirst: Bool, rating: Rating) -> Double {
        if isFirst {
            switch rating {
            case .again: return 600.0
            case .hard: return 1800.0
            case .good: return 3600.0
            case .easy: return 86400.0
            }
        }

        let difficultyFactor = 1.0 - (difficulty * 0.05)
        let baseInterval = switch rating {
        case .again: stability * 0.25
        case .hard: stability * 1.2
        case .good: stability * 2.5
        case .easy: stability * 2.5 * 1.3
        }

        let goodCalculated = max(baseInterval * difficultyFactor, 1800.0)

        return switch rating {
        case .again: max(baseInterval, 600.0)
        case .hard: max(baseInterval, 1200.0, goodCalculated * 0.999)
        case .good: goodCalculated
        case .easy: max(baseInterval * difficultyFactor, goodCalculated + 1.0)
        }
    }
}
