import Foundation

/// CSV importer — supports comma-delimited files with header row
/// Full CSV parsing: quoted fields, escaped quotes, commas inside quotes, BOM, CRLF
final class CSVImporter: WordBookImporter {

    func canImport(fileURL: URL) -> Bool {
        fileURL.pathExtension.lowercased() == "csv"
    }

    func importWords(fileURL: URL) throws -> [ImportedWord] {
        let rawContent = try String(contentsOf: fileURL, encoding: .utf8)
        // Strip UTF-8 BOM if present
        let content = rawContent.hasPrefix("\u{FEFF}") ? String(rawContent.dropFirst()) : rawContent
        let rows = parseCSVRows(from: content)

        guard rows.count >= 2 else { return [] }

        // Parse header and detect column indices
        let header = rows[0]
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let indices = detectColumnIndices(header: header)

        var words: [ImportedWord] = []
        for row in rows.dropFirst() {
            let cols = row.map { $0.trimmingCharacters(in: .whitespaces) }

            // Skip empty and structurally incomplete rows. Optional values are
            // still allowed to be empty when their column is present.
            guard !cols.allSatisfy({ $0.isEmpty }) else { continue }
            guard header.count <= 1 || cols.count >= 2 else { continue }
            guard indices.word < cols.count, !cols[indices.word].isEmpty else { continue }

            let word = cols[indices.word]
            let phonetic = optionalField(at: indices.phonetic, in: cols)
            let meaning = optionalField(at: indices.meaning, in: cols)
            let example = optionalField(at: indices.example, in: cols)
            let exampleTr = optionalField(at: indices.exampleTranslation, in: cols)

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

    private func optionalField(at index: Int?, in fields: [String]) -> String? {
        guard let index, fields.indices.contains(index), !fields[index].isEmpty else { return nil }
        return fields[index]
    }

    // MARK: - CSV Line Parsing

    /// Parse CSV content into rows while respecting quoted fields.
    ///
    /// A quoted field may contain commas and line breaks. Two consecutive
    /// quotes inside a quoted field represent one literal quote. An incomplete
    /// final quoted row is ignored as malformed input, matching the importer's
    /// existing best-effort behavior for damaged files.
    private func parseCSVRows(from content: String) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var afterClosingQuote = false
        let scalars = Array(content.unicodeScalars)
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]

            if inQuotes {
                if scalar == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        field.append("\"")
                        index += 2
                    } else {
                        inQuotes = false
                        afterClosingQuote = true
                        index += 1
                    }
                } else {
                    field.append(Character(scalar))
                    index += 1
                }
                continue
            }

            if scalar == "\"" && field.isEmpty {
                inQuotes = true
                index += 1
                continue
            }

            if scalar == "," {
                fields.append(field)
                field = ""
                afterClosingQuote = false
                index += 1
                continue
            }

            if scalar.value == 0x0D || scalar.value == 0x0A {
                fields.append(field)
                rows.append(fields)
                fields = []
                field = ""
                afterClosingQuote = false

                // Treat CRLF as one record separator.
                if scalar.value == 0x0D,
                   index + 1 < scalars.count,
                   scalars[index + 1].value == 0x0A {
                    index += 2
                } else {
                    index += 1
                }
                continue
            }

            // Whitespace after a closing quote is retained here and trimmed by
            // the importer, preserving the previous field-normalization rule.
            if afterClosingQuote {
                afterClosingQuote = false
            }
            field.append(Character(scalar))
            index += 1
        }

        // Do not turn an unterminated quoted field into a partial word.
        guard !inQuotes else { return rows }

        if !fields.isEmpty || !field.isEmpty {
            fields.append(field)
            rows.append(fields)
        }

        return rows
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
    private static let exampleTranslationKeys = ["exampleTranslation", "example_translation", "sentence_translation", "例句翻译"]

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
        let exampleTranslationCol = Self.exampleTranslationKeys.compactMap(indexFor).first

        return ColumnIndices(
            word: wordCol.map { indexFor($0) ?? 0 } ?? 0,
            phonetic: phoneticCol.flatMap { indexFor($0) },
            meaning: meaningCol.flatMap { indexFor($0) },
            example: exampleCol.flatMap { indexFor($0) },
            exampleTranslation: exampleTranslationCol
        )
    }
}
