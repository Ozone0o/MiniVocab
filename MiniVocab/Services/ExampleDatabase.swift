import Foundation
import SQLite3

/// Lightweight wrapper for the local example sentences SQLite database
final class ExampleDatabase {

    private let db: OpaquePointer?
    private let ok: Bool

    init(path: String) {
        var database: OpaquePointer?
        let status = sqlite3_open(path, &database)

        if status == SQLITE_OK {
            self.db = database
            self.ok = ExampleDatabase.verify(db: database!)
        } else {
            self.db = nil
            self.ok = false
        }
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }

    /// Lookup an example sentence for a word.
    /// Normalizes the word internally: lowercased + trimmed.
    func lookup(for word: String) -> String? {
        guard ok, let db = db else { return nil }

        let normalized = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        let sql = "SELECT sentence FROM examples WHERE word = ? LIMIT 1"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }

        // Use SQLITE_TRANSIENT so SQLite copies the string (cString dies after withCString)
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        _ = normalized.withCString { cString in
            sqlite3_bind_text(stmt, 1, cString, -1, transient)
        }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        let column = sqlite3_column_text(stmt, 0)
        if let cString = column {
            return String(cString: cString)
        }
        return nil
    }

    /// Load the database from the bundle
    static func load() -> ExampleDatabase? {
        #if SWIFT_PACKAGE
        // Swift Package builds place resources in the generated module bundle,
        // while an exported app may place them directly in the main bundle.
        let bundlePath = Bundle.main.path(forResource: "examples", ofType: "sqlite")
            ?? Bundle.module.path(forResource: "examples", ofType: "sqlite")
        #else
        let bundlePath = Bundle.main.path(forResource: "examples", ofType: "sqlite")
        #endif

        guard let bundlePath else {
            print("[MiniVocab] examples.sqlite not found in bundle resources")
            return nil
        }
        return ExampleDatabase(path: bundlePath)
    }

    // MARK: - Schema Verification

    private static func verify(db: OpaquePointer) -> Bool {
        let checkSql = "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='examples'"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, checkSql, -1, &stmt, nil) == SQLITE_OK else { return false }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return false }

        let tableCount = sqlite3_column_int(stmt, 0)
        guard tableCount > 0 else { return false }

        let colCheckSql = "PRAGMA table_info(examples)"
        var colStmt: OpaquePointer?
        defer { sqlite3_finalize(colStmt) }

        guard sqlite3_prepare_v2(db, colCheckSql, -1, &colStmt, nil) == SQLITE_OK else { return false }

        var hasWord = false
        var hasSentence = false
        while sqlite3_step(colStmt) == SQLITE_ROW {
            let name = sqlite3_column_text(colStmt, 1)
            if let name {
                let colName = String(cString: name)
                if colName == "word" { hasWord = true }
                if colName == "sentence" { hasSentence = true }
            }
        }

        guard hasWord && hasSentence else { return false }

        let dataSql = "SELECT COUNT(*) FROM examples"
        var dataStmt: OpaquePointer?
        defer { sqlite3_finalize(dataStmt) }

        guard sqlite3_prepare_v2(db, dataSql, -1, &dataStmt, nil) == SQLITE_OK else { return false }
        guard sqlite3_step(dataStmt) == SQLITE_ROW else { return false }

        let rowCount = sqlite3_column_int(dataStmt, 0)
        if rowCount == 0 { return false }

        print("[MiniVocab] examples.sqlite loaded: \(rowCount) entries, schema valid")
        return true
    }
}
