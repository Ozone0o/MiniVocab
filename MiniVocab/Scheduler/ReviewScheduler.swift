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
    /// Calculate the next review interval in seconds for a given rating
    func nextReviewInterval(for state: LearningState, rating: Rating) -> Double

    /// Update learning state based on rating
    func updateState(_ state: inout LearningState, rating: Rating)

    /// Determine state category after update
    func computeState(for state: LearningState) -> String
}
