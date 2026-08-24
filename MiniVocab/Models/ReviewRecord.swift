import Foundation
import SwiftData

@Model
class ReviewRecord {
    var id: String
    var wordId: String
    var reviewedAt: Date
    var rating: Int
    var previousInterval: Double
    var nextInterval: Double

    init(wordId: String, rating: Int, previousInterval: Double = 0, nextInterval: Double = 1) {
        self.id = UUID().uuidString
        self.wordId = wordId
        self.rating = rating
        self.previousInterval = previousInterval
        self.nextInterval = nextInterval
        self.reviewedAt = Date()
    }
}
