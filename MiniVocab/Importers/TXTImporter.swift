import Foundation

/// TXT importer — supports "word<sep>meaning" and "word<tab>meaning" formats
final class TXTImporter: WordBookImporter {

    func canImport(fileURL: URL) -> Bool {
        fileURL.pathExtension.lowercased() == "txt"
    }

    func importWords(fileURL: URL) throws -> [ImportedWord] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var words: [ImportedWord] = []

        for line in lines {
            let parsed = parseLine(line)
            guard let word = parsed.word, !word.isEmpty else { continue }
            words.append(ImportedWord(
                word: word,
                phonetic: parsed.phonetic,
                meaning: parsed.meaning,
                example: parsed.example,
                exampleTranslation: parsed.exampleTranslation
            ))
        }
        return words
    }

    private struct ParsedLine {
        let word: String?
        let phonetic: String?
        let meaning: String?
        let example: String?
        let exampleTranslation: String?
    }

    private func parseLine(_ line: String) -> ParsedLine {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if isHeaderLine(trimmed) {
            return ParsedLine(word: nil, phonetic: nil, meaning: nil, example: nil, exampleTranslation: nil)
        }

        // Try pipe separator: "word | meaning"
        if line.contains("|") {
            let parts = line.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else {
                return ParsedLine(word: line, phonetic: nil, meaning: nil, example: nil, exampleTranslation: nil)
            }
            return detectFormat(parts: parts)
        }

        // Try tab separator: "word\tmeaning"
        if line.contains("\t") {
            let parts = line.components(separatedBy: "\t")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            return detectFormat(parts: parts)
        }

        // Try space-separated: "word meaning" (first word + rest)
        // Skip lines that look like headers
        // Check if line starts with a phonetic prefix: "/.../ word meaning"
        if trimmed.hasPrefix("/"),
           let closingSlash = trimmed.dropFirst().firstIndex(of: "/") {
            let slashEnd = trimmed.index(after: closingSlash)
            let phonetic = String(trimmed[..<slashEnd])
            let rest = trimmed[slashEnd...].trimmingCharacters(in: .whitespaces)
            let restComponents = rest.split(whereSeparator: \.isWhitespace)
            guard !restComponents.isEmpty else {
                return ParsedLine(word: trimmed, phonetic: nil, meaning: nil, example: nil, exampleTranslation: nil)
            }
            return ParsedLine(
                word: String(restComponents[0]),
                phonetic: phonetic,
                meaning: restComponents.dropFirst().joined(separator: " "),
                example: nil,
                exampleTranslation: nil
            )
        }

        let components = trimmed.split(whereSeparator: \.isWhitespace)
        guard components.count >= 2 else {
            return ParsedLine(word: trimmed, phonetic: nil, meaning: nil, example: nil, exampleTranslation: nil)
        }
        return ParsedLine(
            word: String(components[0]),
            phonetic: nil,
            meaning: components.dropFirst().joined(separator: " "),
            example: nil,
            exampleTranslation: nil
        )
    }

    private func detectFormat(parts: [String]) -> ParsedLine {
        guard parts.count >= 2 else {
            return ParsedLine(word: parts.first, phonetic: nil, meaning: nil, example: nil, exampleTranslation: nil)
        }

        // Check if first part looks like a phonetic (starts with /)
        if parts[0].hasPrefix("/"), parts.count >= 3 {
            return ParsedLine(
                word: parts[1],
                phonetic: parts[0],
                meaning: parts[2...].joined(separator: " "),
                example: nil,
                exampleTranslation: nil
            )
        }

        return ParsedLine(
            word: parts[0],
            phonetic: nil,
            meaning: parts[1...].joined(separator: " "),
            example: nil,
            exampleTranslation: nil
        )
    }

    private func isHeaderLine(_ line: String) -> Bool {
        let parts = line.split(whereSeparator: \.isWhitespace).map { $0.lowercased() }
        guard let first = parts.first else { return false }

        let wordHeaders = ["word", "english", "term", "vocabulary", "单词"]
        let meaningHeaders = ["meaning", "definition", "translation", "chinese", "释义", "中文"]

        if parts.count == 1 {
            return wordHeaders.contains(first) || meaningHeaders.contains(first)
        }

        return wordHeaders.contains(first) && meaningHeaders.contains(parts[1])
    }
}
