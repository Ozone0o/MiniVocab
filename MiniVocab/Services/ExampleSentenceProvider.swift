import Foundation

/// Protocol for fetching example sentences
protocol ExampleSentenceProvider {
    func example(for word: String) async -> String?
}

/// Provides example sentences from a local SQLite database
@MainActor
final class LocalExampleDatabaseProvider: ExampleSentenceProvider {

    private let database: ExampleDatabase?

    init() {
        self.database = ExampleDatabase.load()
    }

    func example(for word: String) async -> String? {
        guard let db = database else { return nil }
        let normalized = normalize(word)
        // Direct match first
        if let example = db.lookup(for: normalized) {
            return example
        }
        // Try morphology variations
        if let example = db.lookup(for: baseForm(normalized)) {
            return example
        }
        return nil
    }

    private func normalize(_ word: String) -> String {
        word.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func baseForm(_ word: String) -> String {
        // Lightweight morphology rules
        let result = word

        // Remove common suffixes and try
        let suffixes = ["ing", "ed", "ly", "tion", "s", "es", "ment", "ness"]
        for suffix in suffixes {
            if word.hasSuffix(suffix), suffix != word, word.count > suffix.count + 2 {
                let stem = String(word.dropLast(suffix.count))
                // Don't over-stem: if stem is too short, skip
                if stem.count > 2 {
                    return stem
                }
            }
        }
        return result
    }
}
