import Foundation
import SwiftData

@Model
class Word {
    @Attribute(.unique) var id: String
    var text: String
    var normalizedText: String
    var phonetic: String?
    var meaning: String?
    var example: String?
    var exampleTranslation: String?
    var createdAt: Date

    init(id: String,
         text: String,
         phonetic: String? = nil,
         meaning: String? = nil,
         example: String? = nil,
         exampleTranslation: String? = nil) {
        self.id = id
        self.text = text
        self.normalizedText = text.lowercased().trimmingCharacters(in: .whitespaces)
        self.phonetic = phonetic
        self.meaning = meaning
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.createdAt = Date()
    }
}
