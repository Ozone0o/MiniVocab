import Foundation
import SwiftUI
import SwiftData

/// Service for managing word books (CRUD, importing)
@MainActor
final class WordBookService {
    public let persistence: PersistenceController
    var sessionManager: StudySessionManager?

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

        // Use UUID for book ID, filename only for display name
        let bookId = UUID().uuidString
        let displayName = bookName ?? bookId

        let wordBook = WordBook(id: bookId, name: displayName)
        persistence.modelContainer.mainContext.insert(wordBook)

        for imported in importedWords {
            let wordId = imported.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !wordId.isEmpty else { continue }

            // Deduplicate by normalized word ID
            if let existingWord = existingWord(with: wordId) {
                // Add existing word to this book if not already included
                if (wordBook.words).first(where: { $0.id == existingWord.id }) == nil {
                    wordBook.words.append(existingWord)
                }
                // Fill in empty meaning/example from import
                if existingWord.meaning == nil, let meaning = imported.meaning {
                    existingWord.meaning = meaning
                }
                if existingWord.example == nil, let example = imported.example {
                    existingWord.example = example
                }
            } else {
                let word = Word(
                    id: wordId,
                    text: imported.word,
                    phonetic: imported.phonetic,
                    meaning: imported.meaning,
                    example: imported.example,
                    exampleTranslation: imported.exampleTranslation
                )
                persistence.modelContainer.mainContext.insert(word)
                wordBook.words.append(word)
            }
        }

        try persistence.save()
    }

    func deleteWordBook(id: String) throws {
        let books = try persistence.fetchAllWordBooks()
        guard let book = books.first(where: { $0.id == id }) else { return }

        // Get all words in this book before deleting the book
        let wordIds = Set((book.words).map(\.id))

        // Delete the book
        persistence.modelContainer.mainContext.delete(book)

        // Clean up orphaned learning data
        try cleanupOrphanedData(forWordIds: Array(wordIds))

        // If deleting the active book, clear session
        if book.isEnabled {
            try? sessionManager?.clearSession()
        }
    }

    private func cleanupOrphanedData(forWordIds: [String]) throws {
        let ctx = persistence.modelContainer.mainContext

        // Fetch all remaining words across all remaining books
        let remainingBooks = try persistence.fetchAllWordBooks()
        var remainingWordIds: Set<String> = []
        for book in remainingBooks {
            for word in book.words {
                remainingWordIds.insert(word.id)
            }
        }

        // Delete states and records for words no longer in any book, and delete orphaned Words
        let allStates = try ctx.fetch(FetchDescriptor<LearningState>())
        for state in allStates {
            if forWordIds.contains(state.wordId) && !remainingWordIds.contains(state.wordId) {
                ctx.delete(state)
            }
        }

        let allRecords = try ctx.fetch(FetchDescriptor<ReviewRecord>())
        for record in allRecords {
            if forWordIds.contains(record.wordId) && !remainingWordIds.contains(record.wordId) {
                ctx.delete(record)
            }
        }

        // Delete orphaned Words (no longer referenced by any WordBook)
        let allWords = try ctx.fetch(FetchDescriptor<Word>())
        for word in allWords {
            if forWordIds.contains(word.id) && !remainingWordIds.contains(word.id) {
                ctx.delete(word)
            }
        }

        try ctx.save()
    }

    // MARK: - Activate Word Book

    /// Activate a word book for study.
    /// - Responsibility: update DB (only this book enabled), then start session.
    func activateWordBook(id: String) throws {
        let books = try persistence.fetchAllWordBooks()
        guard let book = books.first(where: { $0.id == id }) else { return }

        // Disable all, enable selected — DB is the single source of truth for which book is active
        for b in books {
            b.isEnabled = (b.id == id)
        }
        try persistence.save()

        // Start session: load book words into the session manager (does NOT modify WordBook.isEnabled)
        let wordIds = book.words.map(\.id)
        try sessionManager?.startSession(for: book, wordIds: wordIds)
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
        let books = try persistence.fetchAllWordBooks()
        guard let book = books.first(where: { $0.id == bookId }) else { return 0 }
        return (book.words).count
    }

    private func existingWord(with normalizedText: String) -> Word? {
        try? persistence.fetchWord(id: normalizedText)
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
