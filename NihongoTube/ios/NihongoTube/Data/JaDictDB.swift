import Foundation

/// 앱에 들어 있는 jadict.db (표 e: k 표제어, v 항목 JSON).
/// 탭할 때마다 그 첫 글자로 시작하는 표제어를 한 번에 읽어 메모리에 둔다.
final class JaDictDB: JaDictStore {
    private let db: SQLiteDB
    private let lock = NSLock()
    /// 첫 글자 → (표제어 → 항목 JSON)
    private var groups: [Character: [String: String]] = [:]
    private var order: [Character] = []
    private var decoded: [String: [DictEntry]] = [:]

    init(path: String) throws {
        db = try SQLiteDB(path: path)
    }

    static func bundled() throws -> JaDictDB {
        guard let url = Bundle.main.url(forResource: "jadict", withExtension: "db") else {
            throw SQLiteError(message: "앱 안에 사전 파일(jadict.db)이 없어요")
        }
        return try JaDictDB(path: url.path)
    }

    func prepare(firstChar: Character) {
        lock.lock()
        defer { lock.unlock() }
        if groups[firstChar] != nil { return }
        let lo = String(firstChar)
        // 첫 글자 다음 코드 값 = 이 글자로 시작하는 모든 표제어보다 큰 값
        guard let last = lo.unicodeScalars.last, let next = Unicode.Scalar(last.value + 1) else { return }
        let hi = String(lo.unicodeScalars.dropLast()) + String(next)
        var map: [String: String] = [:]
        for row in db.query("SELECT k, v FROM e WHERE k >= ? AND k < ?", [.text(lo), .text(hi)]) {
            if let k = row.string("k"), let v = row.string("v") { map[k] = v }
        }
        groups[firstChar] = map
        order.append(firstChar)
        // 메모리 아끼기: 최근 40글자만
        if order.count > 40 {
            let old = order.removeFirst()
            groups[old] = nil
        }
    }

    func entries(_ key: String) -> [DictEntry]? {
        lock.lock()
        defer { lock.unlock() }
        if let d = decoded[key] { return d }
        guard let first = key.first else { return nil }
        let raw: String?
        if let g = groups[first] {
            raw = g[key]
        } else {
            raw = db.query("SELECT v FROM e WHERE k = ?", [.text(key)]).first?.string("v")
        }
        guard let raw else { return nil }
        let list = DictEntry.decodeList(raw)
        if decoded.count > 4000 { decoded.removeAll() }
        decoded[key] = list
        return list
    }
}
