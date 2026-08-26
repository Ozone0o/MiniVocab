import Foundation
import SwiftData

@Model
class WordBook {
    var id: String
    var name: String
    var createdAt: Date
    var isEnabled: Bool

    @Relationship(deleteRule: .nullify)
    var words: [Word] = []

    init(id: String, name: String) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.isEnabled = false
    }
}
