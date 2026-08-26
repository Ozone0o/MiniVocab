import Foundation

/// Rating levels for word review
enum Rating: Int, CaseIterable {
    case again = 1   // Forget
    case hard        // Blur
    case good        // Know
    case easy        // Master

    var localized: String {
        switch self {
        case .again: return "忘记"
        case .hard: return "模糊"
        case .good: return "认识"
        case .easy: return "熟知"
        }
    }
}

/// Scheduler protocol for spaced repetition
protocol ReviewScheduler {
    /// Apply a rating to a learning state: update state and return the computed interval in one call.
    func apply(_ rating: Rating, to state: inout LearningState) -> Double

    /// Determine state category after update
    func computeState(for state: LearningState) -> String
}
