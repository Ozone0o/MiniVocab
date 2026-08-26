import Foundation

/// JSON importer — expects an array of objects with optional fields
final class JSONImporter: WordBookImporter {

    func canImport(fileURL: URL) -> Bool {
        fileURL.pathExtension.lowercased() == "json"
    }

    func importWords(fileURL: URL) throws -> [ImportedWord] {
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode([JSONWordEntry].self, from: data)

        return decoded.compactMap { entry -> ImportedWord? in
            guard let word = entry._word, !word.trimmingCharacters(in: .whitespaces).isEmpty else {
                return nil
            }
            return ImportedWord(
                word: word,
                phonetic: entry.phonetic,
                meaning: entry._meaning,
                example: entry._example,
                exampleTranslation: entry._exampleTranslation
            )
        }
    }
}

// MARK: - JSON decoding helper

private struct JSONWordEntry: Decodable {
    let word: String?
    let english: String?
    let term: String?
    let vocabulary: String?
    let meaning: String?
    let definition: String?
    let translation: String?
    let chinese: String?
    let phonetic: String?
    let example: String?
    let example_translation: String?
    let sentence: String?
    let sentence_translation: String?
    let context: String?

    enum CodingKeys: String, CodingKey {
        case word, english, term, vocabulary
        case meaning, definition, translation, chinese, phonetic
        case example, example_translation, sentence, sentence_translation, context
    }

    var _word: String? {
        word ?? english ?? term ?? vocabulary
    }

    var _meaning: String? {
        meaning ?? definition ?? translation ?? chinese
    }

    var _example: String? {
        example ?? sentence ?? context
    }

    var _exampleTranslation: String? {
        example_translation ?? sentence_translation
    }
}

extension JSONWordEntry {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONWordEntry.CodingKeys.self)
        word = try container.decodeIfPresent(String.self, forKey: .word)
        english = try container.decodeIfPresent(String.self, forKey: .english)
        term = try container.decodeIfPresent(String.self, forKey: .term)
        vocabulary = try container.decodeIfPresent(String.self, forKey: .vocabulary)
        meaning = try container.decodeIfPresent(String.self, forKey: .meaning)
        definition = try container.decodeIfPresent(String.self, forKey: .definition)
        translation = try container.decodeIfPresent(String.self, forKey: .translation)
        chinese = try container.decodeIfPresent(String.self, forKey: .chinese)
        phonetic = try container.decodeIfPresent(String.self, forKey: .phonetic)
        example = try container.decodeIfPresent(String.self, forKey: .example)
        example_translation = try container.decodeIfPresent(String.self, forKey: .example_translation)
        sentence = try container.decodeIfPresent(String.self, forKey: .sentence)
        sentence_translation = try container.decodeIfPresent(String.self, forKey: .sentence_translation)
        context = try container.decodeIfPresent(String.self, forKey: .context)
    }
}
