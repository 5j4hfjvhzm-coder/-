import Foundation

/// 앱에 내장된 dict.db(scripts/build_dict.py 결과) 위의 DictStore
final class SQLDictStore: DictStore {
    private let db: SQLiteDB
    private let chunk = 400

    init(path: String) throws {
        db = try SQLiteDB(path: path, readOnly: true)
    }

    /// 앱 번들의 dict.db
    static func bundled() throws -> SQLDictStore {
        guard let path = Bundle.main.path(forResource: "dict", ofType: "db") else {
            throw SQLiteError(message: "앱 번들에 dict.db 가 없어요")
        }
        return try SQLDictStore(path: path)
    }

    private func marks(_ n: Int) -> String {
        Array(repeating: "?", count: n).joined(separator: ",")
    }

    private func chunked(_ items: [SQLValue], _ run: ([SQLValue]) -> [SQLRow]) -> [SQLRow] {
        stride(from: 0, to: items.count, by: chunk).flatMap { i in
            run(Array(items[i..<min(items.count, i + chunk)]))
        }
    }

    func lemmasOf(_ forms: [String]) -> [FormRow] {
        let params = uniqued(forms).map { SQLValue.text($0) }
        guard !params.isEmpty else { return [] }
        return chunked(params) { part in
            db.query("SELECT form, lemma, tags FROM forms WHERE form IN (\(marks(part.count)))", part)
        }.map { FormRow(form: $0.string("form") ?? "", lemma: $0.string("lemma") ?? "", tags: $0.string("tags") ?? "") }
    }

    func formsOf(_ lemma: String) -> [String] {
        uniqued(db.query("SELECT form FROM forms WHERE lemma = ?", [.text(lemma)]).compactMap { $0.string("form") })
    }

    func entriesFor(_ words: [String]) -> [Entry] {
        let params = uniqued(words).map { SQLValue.text($0) }
        guard !params.isEmpty else { return [] }
        let rows = chunked(params) { part in
            db.query("SELECT id, word, pos, source, ipa, ko FROM entries WHERE word_lower IN (\(marks(part.count))) ORDER BY id", part)
        }
        guard !rows.isEmpty else { return [] }
        let ids = rows.map { SQLValue.int($0.int("id")) }
        let senseRows = chunked(ids) { part in
            db.query("SELECT id, entry_id, gloss, tags, examples, ko FROM senses WHERE entry_id IN (\(marks(part.count))) ORDER BY entry_id, idx", part)
        }
        var byEntry: [Int: [Sense]] = [:]
        for s in senseRows {
            byEntry[s.int("entry_id"), default: []].append(Sense(
                id: s.int("id"),
                gloss: s.string("gloss") ?? "",
                tags: (s.string("tags") ?? "").split(separator: " ").map(String.init),
                examples: decodeExamples(s.string("examples")),
                ko: decodeStrings(s.string("ko"))
            ))
        }
        return rows.map { r in
            Entry(
                id: r.int("id"),
                word: r.string("word") ?? "",
                pos: r.string("pos") ?? "",
                source: r.string("source") == "ko" ? .ko : .en,
                senses: byEntry[r.int("id")] ?? [],
                ipa: r.string("ipa"),
                ko: decodeStrings(r.string("ko"))
            )
        }
    }

    func phrasesStartingWith(_ firsts: [String]) -> [String] {
        let params = uniqued(firsts).map { SQLValue.text($0) }
        guard !params.isEmpty else { return [] }
        return uniqued(chunked(params) { part in
            db.query("SELECT phrase FROM phrases WHERE first IN (\(marks(part.count)))", part)
        }.compactMap { $0.string("phrase") })
    }

    func searchPrefix(_ prefix: String, limit: Int) -> [String] {
        let p = prefix.lowercased()
        guard !p.isEmpty else { return [] }
        return db.query(
            "SELECT DISTINCT word_lower FROM entries WHERE word_lower >= ? AND word_lower < ? ORDER BY word_lower LIMIT ?",
            [.text(p), .text(p + "\u{FFFF}"), .int(limit)]
        ).compactMap { $0.string("word_lower") }
    }
}

private func decodeStrings(_ s: String?) -> [String] {
    guard let data = s?.data(using: .utf8),
          let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
    return arr.compactMap { $0 as? String }
}

private func decodeExamples(_ s: String?) -> [Example] {
    guard let data = s?.data(using: .utf8),
          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
    return arr.compactMap { d in
        guard let text = d["text"] as? String else { return nil }
        return Example(text: text, ko: d["ko"] as? String)
    }
}
