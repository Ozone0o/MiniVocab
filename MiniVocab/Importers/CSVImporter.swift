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

    private func detectColumnIndices(header: [String]) -> ColumnIndices {
        let indexFor = { (column: FieldColumn) -> Int? in
            header.firstIndex { $0 == column.rawValue }
        }

        // Word column: first match among word synonyms
        let wordCol = FieldColumn.allCases.first { header.contains($0.rawValue) }

        // Meaning column: first match among meaning synonyms, excluding word
        let meaningCol = FieldColumn.allCases.first { col in
            col != wordCol && header.contains(col.rawValue)
        }

        // Phonetic
        let phoneticCol = FieldColumn.allCases.first { col in
            col != .word && col != .meaning && col != .example && col != .exampleTranslation
            && header.contains(col.rawValue)
        }

        // Example (but not exampleTranslation)
        let exampleCol = FieldColumn.allCases.first { col in
            (col == .example || col == .context || col == .sentence || col == .example_sentence)
            && header.contains(col.rawValue)
        }

        // Example translation
        let exampleTranslationCol: FieldColumn?
        if let et = FieldColumn.allCases.first(where: { $0 == .exampleTranslation && header.contains($0.rawValue) }) {
            exampleTranslationCol = et
        } else if let et = FieldColumn.allCases.first(where: { $0 == .sentence_translation && header.contains($0.rawValue) }) {
            exampleTranslationCol = et
        } else if let et = FieldColumn.allCases.first(where: { $0.rawValue == "例句翻译" && header.contains($0.rawValue) }) {
            exampleTranslationCol = et
        } else {
            exampleTranslationCol = nil
        }

        return ColumnIndices(
            word: wordCol.map { indexFor($0) ?? 0 } ?? 0,
            phonetic: phoneticCol.flatMap { indexFor($0) },
            meaning: (meaningCol ?? wordCol).flatMap { indexFor($0) },
            example: exampleCol.flatMap { indexFor($0) },
            exampleTranslation: exampleTranslationCol.flatMap { indexFor($0) }
        )
    }
}
