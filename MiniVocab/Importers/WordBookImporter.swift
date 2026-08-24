import Foundation

/// Protocol for word book file importers
protocol WordBookImporter {
    /// Check if this importer can handle the given file
    func canImport(fileURL: URL) -> Bool

    /// Import words from the given file
    func importWords(fileURL: URL) throws -> [ImportedWord]
}

/// Represents a word parsed from an import file, before persisting
struct ImportedWord {
    let word: String
    let phonetic: String?
    let meaning: String?
    let example: String?
    let exampleTranslation: String?
}

/// Field types for CSV/TSV column mapping
enum FieldColumn: String, CaseIterable {
    case word, english, term, vocabulary, 单词
    case meaning, definition, translation, chinese,释义, 中文
    case phonetic
    case example, sentence, example_sentence, context, 例句
    case exampleTranslation, sentence_translation, 例句翻译
    case unknown = "—"

    var displayName: String {
        rawValue
    }
}
