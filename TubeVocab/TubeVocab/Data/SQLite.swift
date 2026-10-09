import Foundation
import SQLite3

/// 아주 얇은 SQLite 래퍼 (읽기 전용 사전용)
enum SQLValue: Equatable {
    case text(String)
    case int(Int)
    case null
}

struct SQLRow {
    fileprivate var values: [String: SQLValue]

    func string(_ key: String) -> String? {
        switch values[key] {
        case .text(let s): return s
        case .int(let i): return String(i)
        default: return nil
        }
    }

    func int(_ key: String) -> Int {
        switch values[key] {
        case .int(let i): return i
        case .text(let s): return Int(s) ?? 0
        default: return 0
        }
    }
}

struct SQLiteError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteDB {
    private var db: OpaquePointer?

    init(path: String, readOnly: Bool = true) throws {
        let flags = (readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)) | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "열 수 없음"
            sqlite3_close(db)
            db = nil
            throw SQLiteError(message: "\(path): \(msg)")
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func query(_ sql: String, _ params: [SQLValue] = []) -> [SQLRow] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in params.enumerated() {
            let idx = Int32(i + 1)
            switch p {
            case .text(let s): sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            case .int(let v): sqlite3_bind_int64(stmt, idx, Int64(v))
            case .null: sqlite3_bind_null(stmt, idx)
            }
        }
        var rows: [SQLRow] = []
        let n = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var values: [String: SQLValue] = [:]
            for c in 0..<n {
                let name = String(cString: sqlite3_column_name(stmt, c))
                switch sqlite3_column_type(stmt, c) {
                case SQLITE_INTEGER:
                    values[name] = .int(Int(sqlite3_column_int64(stmt, c)))
                case SQLITE_NULL:
                    values[name] = .null
                default:
                    if let t = sqlite3_column_text(stmt, c) {
                        values[name] = .text(String(cString: t))
                    } else {
                        values[name] = .null
                    }
                }
            }
            rows.append(SQLRow(values: values))
        }
        return rows
    }
}
