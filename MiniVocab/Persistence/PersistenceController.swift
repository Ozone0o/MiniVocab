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

    func fetchOverdueReviews() throws -> [Word] {
        let now = Date()
        let states = try modelContainer.mainContext.fetch(FetchDescriptor<LearningState>())
        let overdueWordIds = states
            .filter { $0.nextReviewAt != nil && $0.nextReviewAt! <= now && $0.state != "New" }
            .map { $0.wordId }
        return wordsById(overdueWordIds)
    }

    func fetchDifficultWords() throws -> [Word] {
        let states = try modelContainer.mainContext.fetch(FetchDescriptor<LearningState>())
        let difficultWordIds = states
            .filter { $0.state == "Difficult" || $0.forgetCount >= 3 }
            .map { $0.wordId }
        return wordsById(difficultWordIds)
    }

    func fetchNewWords(limit: Int) throws -> [Word] {
        let states = try modelContainer.mainContext.fetch(FetchDescriptor<LearningState>())
        let newWordIds = states.filter { $0.state == "New" }.map { $0.wordId }
        guard !newWordIds.isEmpty else { return [] }
        let words = allWords().filter { newWordIds.contains($0.id) }
        return Array(words.sorted { $0.createdAt < $1.createdAt }.prefix(limit))
    }

    func fetchReviewedWordIds() throws -> Set<String> {
        let states = try modelContainer.mainContext.fetch(FetchDescriptor<LearningState>())
        return Set(states.filter { $0.lastReviewedAt != nil }.map { $0.wordId })
    }

    func fetchReviewRecords(for wordId: String) throws -> [ReviewRecord] {
        let descriptor = FetchDescriptor<ReviewRecord>(sortBy: [SortDescriptor(\.reviewedAt, order: .reverse)])
        let all = try modelContainer.mainContext.fetch(descriptor)
        return all.filter { $0.wordId == wordId }
    }

    // MARK: - Helpers

    private func allWords() -> [Word] {
        return try! modelContainer.mainContext.fetch(FetchDescriptor<Word>())
    }

    private func allLearningStates() -> [LearningState] {
        return try! modelContainer.mainContext.fetch(FetchDescriptor<LearningState>())
    }

    private func wordsById(_ ids: [String]) -> [Word] {
        guard !ids.isEmpty else { return [] }
        return allWords().filter { ids.contains($0.id) }
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
