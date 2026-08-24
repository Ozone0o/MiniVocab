import Foundation
import SQLite3

/// Lightweight wrapper for the local example sentences SQLite database
final class ExampleDatabase {

    private var db: OpaquePointer?

    let path: String

    init(path: String) {
        self.path = path
    }

    deinit {
        sqlite3_close(db)
    }

    /// Lookup an example sentence for a word
    func lookup(for word: String) -> String? {
        guard let db = db else { return nil }

        let sql = "SELECT sentence FROM examples WHERE word = ? LIMIT 1"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }

        let wordBytes = [UInt8](word.utf8)
        wordBytes.withUnsafeBufferPointer { ptr in
            sqlite3_bind_text(stmt, 1, ptr.baseAddress, -1, nil)
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
        // Try to find the database in the bundle resources
        guard let bundlePath = Bundle.main.path(forResource: "examples", ofType: "sqlite") else {
            return nil
        }
        let db = ExampleDatabase(path: bundlePath)
        if sqlite3_open(db.path, &db.db) == SQLITE_OK {
            return db
        }
        return nil
    }
}

private extension Array where Element == Int8 {
    func variadicPointer<T>(_ body: (UnsafePointer<Int8>) -> T) -> T? {
        withUnsafeBufferPointer { ptr in
            body(ptr.baseAddress!)
        }
    }
}
