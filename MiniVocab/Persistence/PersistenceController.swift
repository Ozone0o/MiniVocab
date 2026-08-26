import Foundation
import SwiftData
import SwiftUI

/// Central SwiftData container for MiniVocab.
@MainActor
public struct PersistenceController {
    static let preview: PersistenceController = {
        let container = try! ModelContainer(for: Word.self, WordBook.self, ReviewRecord.self, LearningState.self)
        return PersistenceController(modelContainer: container)
    }()

    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

public init(isPreview: Bool = false) {
        if isPreview {
            self.modelContainer = PersistenceController.preview.modelContainer
        } else {
            let schema = Schema([Word.self, WordBook.self, ReviewRecord.self, LearningState.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    // MARK: - Queries

    func fetchWords() throws -> [Word] {
        let descriptor = FetchDescriptor<Word>()
        return try modelContainer.mainContext.fetch(descriptor)
    }

    func fetchWord(id: String) throws -> Word? {
        let descriptor = FetchDescriptor<Word>()
        let results = try modelContainer.mainContext.fetch(descriptor)
        return results.first { $0.id == id }
    }

    func fetchEnabledWordBooks() throws -> [WordBook] {
        let descriptor = FetchDescriptor<WordBook>()
        let results = try modelContainer.mainContext.fetch(descriptor)
        return results.filter { $0.isEnabled == true }
    }

    func fetchAllWordBooks() throws -> [WordBook] {
        try modelContainer.mainContext.fetch(FetchDescriptor<WordBook>())
    }

    func fetchLearningState(wordId: String) throws -> LearningState? {
        let descriptor = FetchDescriptor<LearningState>()
        let results = try modelContainer.mainContext.fetch(descriptor)
        return results.first { $0.wordId == wordId }
    }

    func fetchOrCreateLearningState(wordId: String) throws -> LearningState {
        if let existing = try fetchLearningState(wordId: wordId) {
            return existing
        }
        let state = LearningState(wordId: wordId)
        modelContainer.mainContext.insert(state)
        return state
    }

    func fetchReviewRecords(for wordId: String) throws -> [ReviewRecord] {
        let descriptor = FetchDescriptor<ReviewRecord>(sortBy: [SortDescriptor(\.reviewedAt, order: .reverse)])
        let all = try modelContainer.mainContext.fetch(descriptor)
        return all.filter { $0.wordId == wordId }
    }

    // MARK: - Save

    func save() throws {
        try modelContainer.mainContext.save()
    }
}

// MARK: - Date Extension

extension Date {
    func toISO() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }

    static func fromISO(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
}
