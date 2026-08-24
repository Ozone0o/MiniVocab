import Foundation
import SwiftData

@Model
public class LearningState {
    var wordId: String
    var difficulty: Double
    var stability: Double
    var reviewCount: Int
    var forgetCount: Int
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
    var lastRating: Int?
    var state: String  // "New", "Learning", "Review", "Difficult", "Mastered"

    init(wordId: String,
         difficulty: Double = 0.0,
         stability: Double = 0.0,
         reviewCount: Int = 0,
         forgetCount: Int = 0,
         state: String = "New") {
        self.wordId = wordId
        self.difficulty = difficulty
        self.stability = stability
        self.reviewCount = reviewCount
        self.forgetCount = forgetCount
        self.state = state
    }
}
