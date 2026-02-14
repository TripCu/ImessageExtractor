import Foundation
import SQLite3

enum DBError: Error, CustomStringConvertible {
    case fileMissing
    case openFailed(code: Int32, message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)

    var description: String {
        switch self {
        case .fileMissing: return "Messages database file is missing"
        case let .openFailed(code, message): return "SQLite open failed (\(code)): \(message)"
        case let .prepareFailed(message): return "SQLite prepare failed: \(message)"
        case let .stepFailed(message): return "SQLite step failed: \(message)"
        }
    }
}

final class SQLiteReadOnly {
    private var db: OpaquePointer?
    let path: String

    init(path: String) throws {
        self.path = path
        guard FileManager.default.fileExists(atPath: path) else { throw DBError.fileMissing }
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(path, &handle, flags, nil)
        guard rc == SQLITE_OK, let handle else {
            let message: String
            if let handle {
                message = String(cString: sqlite3_errmsg(handle))
            } else {
                message = "Unknown SQLite open error"
            }
            throw DBError.openFailed(code: rc, message: message)
        }
        db = handle
    }

    deinit { sqlite3_close(db) }

    func queryRows(sql: String) throws -> [[String: SQLiteValue]] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        var rows: [[String: SQLiteValue]] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW {
                let count = sqlite3_column_count(stmt)
                var row: [String: SQLiteValue] = [:]
                for i in 0..<count {
                    let name = String(cString: sqlite3_column_name(stmt, i))
                    row[name] = SQLiteValue.from(stmt: stmt, index: i)
                }
                rows.append(row)
            } else if rc == SQLITE_DONE {
                break
            } else {
                throw DBError.stepFailed(message: String(cString: sqlite3_errmsg(db)))
            }
        }
        return rows
    }
}

enum SQLiteValue {
    case int(Int64)
    case double(Double)
    case text(String)
    case blob(Data)
    case null

    static func from(stmt: OpaquePointer?, index: Int32) -> SQLiteValue {
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_INTEGER: return .int(sqlite3_column_int64(stmt, index))
        case SQLITE_FLOAT: return .double(sqlite3_column_double(stmt, index))
        case SQLITE_TEXT:
            if let ptr = sqlite3_column_text(stmt, index) { return .text(String(cString: ptr)) }
            return .null
        case SQLITE_BLOB:
            let bytes = sqlite3_column_blob(stmt, index)
            let length = Int(sqlite3_column_bytes(stmt, index))
            if let bytes, length > 0 { return .blob(Data(bytes: bytes, count: length)) }
            return .blob(Data())
        default: return .null
        }
    }

    var string: String? { if case let .text(v) = self { return v }; return nil }
    var int64: Int64? { if case let .int(v) = self { return v }; return nil }
}
