import Foundation

/// CSV importer — supports comma-delimited files with header row
final class CSVImporter: WordBookImporter {

    func canImport(fileURL: URL) -> Bool {
        fileURL.pathExtension.lowercased() == "csv"
    }

    func importWords(fileURL: URL) throws -> [ImportedWord] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return [] }

        // Parse header and detect column indices
        let header = lines[0].components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let indices = detectColumnIndices(header: header)

        var words: [ImportedWord] = []
        for line in lines[1...] {
            let cols = line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard indices.word < cols.count, !cols[indices.word].isEmpty else { continue }

            let word = cols[indices.word]
            let phonetic = indices.phonetic.flatMap { $0 < cols.count ? cols[$0] : nil }
            let meaning = indices.meaning.flatMap { $0 < cols.count ? cols[$0] : nil }
            let example = indices.example.flatMap { $0 < cols.count ? cols[$0] : nil }
            let exampleTr = indices.exampleTranslation.flatMap { $0 < cols.count ? cols[$0] : nil }

            words.append(ImportedWord(
                word: word,
                phonetic: phonetic,
                meaning: meaning,
                example: example,
                exampleTranslation: exampleTr
            ))
        }
        return words
    }

    // MARK: - Column Detection

    private struct ColumnIndices {
        let word: Int
        let phonetic: Int?
        let meaning: Int?
        let example: Int?
        let exampleTranslation: Int?
    }

    private static let wordKeys = ["word", "english", "term", "vocabulary", "单词"]
    private static let meaningKeys = ["meaning", "definition", "translation", "chinese", "释义", "中文"]
    private static let phoneticKeys = ["phonetic", "ipa", "pronunciation", "音标"]
    private static let exampleKeys = ["example", "sentence", "context", "example_sentence", "例句"]

    private func detectColumnIndices(header: [String]) -> ColumnIndices {
        let indexFor = { (column: String) -> Int? in
            header.firstIndex { $0 == column }
        }

        // Word column: first match among word keys
        let wordCol = Self.wordKeys.first { header.contains($0) }

        // Meaning column: first match among meaning keys, excluding word
        let meaningCol = Self.meaningKeys.first { header.contains($0) }

        // Phonetic
        let phoneticCol = Self.phoneticKeys.first { header.contains($0) }

        // Example
        let exampleCol = Self.exampleKeys.first { header.contains($0) }

        // Example translation
        let exampleTranslationCol: Int?
        if let idx = indexFor("example_translation") {
            exampleTranslationCol = idx
        } else if let idx = indexFor("sentence_translation") {
            exampleTranslationCol = idx
        } else if let idx = indexFor("例句翻译") {
            exampleTranslationCol = idx
        } else {
            exampleTranslationCol = nil
        }

        return ColumnIndices(
            word: wordCol.map { indexFor($0) ?? 0 } ?? 0,
            phonetic: phoneticCol.flatMap { indexFor($0) },
            meaning: meaningCol.flatMap { indexFor($0) },
            example: exampleCol.flatMap { indexFor($0) },
            exampleTranslation: exampleTranslationCol
        )
    }
}
