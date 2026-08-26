import Foundation

/// TSV importer — tab-separated files
final class TSVImporter: WordBookImporter {

    func canImport(fileURL: URL) -> Bool {
        fileURL.pathExtension.lowercased() == "tsv"
    }

    func importWords(fileURL: URL) throws -> [ImportedWord] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return [] }

        let header = lines[0].components(separatedBy: "\t")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let indices = detectColumnIndices(header: header)

        var words: [ImportedWord] = []
        for line in lines[1...] {
            let cols = line.components(separatedBy: "\t")
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

        let wordCol = Self.wordKeys.first { header.contains($0) }
        let meaningCol = Self.meaningKeys.first { header.contains($0) }
        let phoneticCol = Self.phoneticKeys.first { header.contains($0) }
        let exampleCol = Self.exampleKeys.first { header.contains($0) }

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
