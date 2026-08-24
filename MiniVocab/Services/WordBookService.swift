import Foundation
import SwiftData

/// Service for managing word books (CRUD, importing)
@MainActor
final class WordBookService {

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    // MARK: - CRUD

    /// Import words from a file, using the first compatible importer
    func importFromFile(fileURL: URL, bookName: String?) throws {
        let importers: [WordBookImporter] = [CSVImporter(), TSVImporter(), TXTImporter(), JSONImporter()]
        let importer = importers.first { $0.canImport(fileURL: fileURL) }
        guard let importer else {
            throw ImportError.unsupportedFormat(fileURL.pathExtension)
        }

        let importedWords = try importer.importWords(fileURL: fileURL)
        guard !importedWords.isEmpty else { return }

        let bookId = bookName?
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased() ?? UUID().uuidString

        let wordBook = WordBook(id: bookId, name: bookName ?? bookId)
        persistence.modelContainer.mainContext.insert(wordBook)

        var insertedCount = 0
        for imported in importedWords {
            let wordId = imported.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !wordId.isEmpty else { continue }

            // Deduplicate by normalized word
            if existingWord(with: wordId) != nil {
                insertedCount += 1 // count but skip insert
                continue
            }

            let word = Word(
                id: wordId,
                text: imported.word,
                phonetic: imported.phonetic,
                meaning: imported.meaning,
                example: imported.example,
                exampleTranslation: imported.exampleTranslation
            )
            persistence.modelContainer.mainContext.insert(word)
            insertedCount += 1
        }

        try persistence.save()
    }

    func deleteWordBook(id: String) throws {
        let books = try persistence.fetchAllWordBooks()
        guard let book = books.first(where: { $0.id == id }) else { return }
        persistence.modelContainer.mainContext.delete(book)
        try persistence.save()
    }

    func toggleWordBook(id: String, enabled: Bool) throws {
        let books = try persistence.fetchAllWordBooks()
        guard let book = books.first(where: { $0.id == id }) else { return }
        book.isEnabled = enabled
        try persistence.save()
    }

    func renameWordBook(id: String, newName: String) throws {
        let books = try persistence.fetchAllWordBooks()
        guard let book = books.first(where: { $0.id == id }) else { return }
        book.name = newName
        try persistence.save()
    }

    // MARK: - Queries

    func fetchWordBooks() throws -> [WordBook] {
        try persistence.fetchAllWordBooks()
    }

    func countWords(in bookId: String) throws -> Int {
        let words = try? persistence.fetchWords()
        return words?.count ?? 0
    }

    private func existingWord(with normalizedText: String) -> Word? {
        try? persistence.fetchWord(id: normalizedText)
    }

    // MARK: - Example Enrichment

    func enrichExamplesInBackground() throws {
        let words = try persistence.fetchWords()
        let wordsWithoutExample = words.filter { $0.example == nil && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !wordsWithoutExample.isEmpty else { return }

        // Copy word data out of MainActor context to avoid sending issues
        let wordData = wordsWithoutExample.map { ($0.id, $0.text) }

        Task.detached {
            let provider = await MainActor.run { LocalExampleDatabaseProvider() }

            for (index, (wordId, wordText)) in wordData.enumerated() {
                if let example = await provider.example(for: wordText) {
                    await MainActor.run {
                        let ctx = PersistenceController().modelContainer.mainContext
                        if let target = (try? ctx.fetch(FetchDescriptor<Word>()))?.first(where: { $0.id == wordId }) {
                            target.example = example
                            try? ctx.save()
                        }
                    }
                }

                if index % 100 == 0 {
                    try? Task.checkCancellation()
                }
            }
        }
    }

    // MARK: - Data Export

    func exportLearningData() throws -> Data {
        let words = try persistence.fetchWords()
        let states = try? persistence.modelContainer.mainContext.fetch(FetchDescriptor<LearningState>())
        let records = try? persistence.modelContainer.mainContext.fetch(FetchDescriptor<ReviewRecord>())

        struct RatingEntry: Encodable {
            let date: String
            let rating: Int
        }

        struct ExportEntry: Encodable {
            let word: String
            let meaning: String?
            let state: String?
            let reviewCount: Int?
            let lastReviewed: String?
            let ratings: [RatingEntry]
        }

        var entries: [ExportEntry] = []
        for word in words {
            let state = states?.first(where: { $0.wordId == word.id })
            let wordRecords = records?.filter { $0.wordId == word.id }
            let entry = ExportEntry(
                word: word.text,
                meaning: word.meaning,
                state: state?.state,
                reviewCount: state?.reviewCount,
                lastReviewed: state?.lastReviewedAt?.toISO(),
                ratings: (wordRecords ?? []).map { RatingEntry(date: $0.reviewedAt.toISO(), rating: $0.rating) }
            )
            entries.append(entry)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }

    func resetLearningData() throws {
        let states = try? persistence.modelContainer.mainContext.fetch(FetchDescriptor<LearningState>())
        for state in states ?? [] {
            persistence.modelContainer.mainContext.delete(state)
        }
        let records = try? persistence.modelContainer.mainContext.fetch(FetchDescriptor<ReviewRecord>())
        for record in records ?? [] {
            persistence.modelContainer.mainContext.delete(record)
        }
        try persistence.save()
    }
}

enum ImportError: LocalizedError {
    case unsupportedFormat(String)
    case parsingError(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Unsupported file format: \(ext)"
        case .parsingError(let msg):
            return "Parsing error: \(msg)"
        }
    }
}
