import Foundation

/// 일→한 사전 조회 (사전 데이터는 yomichan-ko-dic 을 뒤집어 만든 jadict.db)

/// 사전 항목 하나: 읽기, 한국어 단어, 한국어 뜻풀이
struct DictEntry: Equatable, Hashable {
    var reading: String
    var ko: String
    var def: String

    /// jadict.db 의 v 칸(JSON 배열의 배열) → 항목들
    static func decodeList(_ json: String) -> [DictEntry] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String]] else { return [] }
        return arr.compactMap { e in
            guard e.count >= 2 else { return nil }
            return DictEntry(reading: e[0], ko: e[1], def: e.count > 2 ? e[2] : "")
        }
    }
}

/// 조회 결과 하나: 문장 속 모양(surface), 기본형(term), 활용 이유, 사전 항목
struct LookupResult: Equatable, Identifiable {
    var surface: String
    /// 문장 안 시작 글자 위치
    var start: Int
    var length: Int
    var term: String
    var reasons: [String]
    var entries: [DictEntry]

    var id: String { "\(start)|\(length)|\(term)" }

    /// 대표 읽기 (항목에 많이 나온 순)
    var readings: [String] {
        var count: [String: Int] = [:]
        var order: [String] = []
        for e in entries where !e.reading.isEmpty {
            if count[e.reading] == nil { order.append(e.reading) }
            count[e.reading, default: 0] += 1
        }
        return order.enumerated().sorted { a, b in
            let ca = count[a.element] ?? 0, cb = count[b.element] ?? 0
            return ca != cb ? ca > cb : a.offset < b.offset
        }.map(\.element)
    }

    var reading: String { readings.first ?? "" }
}

/// 사전 저장소. 같은 첫 글자 표제어를 한 번에 불러오므로 조회 전에 prepare(첫 글자)를 부른다.
protocol JaDictStore: AnyObject {
    func prepare(firstChar: Character)
    func entries(_ key: String) -> [DictEntry]?
}

/// 끊는 글자 (문장부호·공백)
private let stopChars: Set<Character> = Set(" \u{3000}、。！？!?,.・「」『』（）()【】〈〉《》…‥〜~\"'“”‘’♪→\n\t")

/// 문장 text 의 at 번째 글자에서 시작하는 사전 단어를 찾는다 (가장 긴 것부터).
func lookupAt(_ text: String, at: Int, store: JaDictStore, maxLen: Int = 18) -> [LookupResult] {
    let chars = Array(text)
    guard at >= 0, at < chars.count else { return [] }
    var s: [Character] = []
    var i = at
    while i < chars.count && s.count < maxLen && !stopChars.contains(chars[i]) {
        s.append(chars[i])
        i += 1
    }
    guard let first = s.first else { return [] }
    store.prepare(firstChar: first)
    let hiraFirst = Character(toHiragana(String(first)))
    if hiraFirst != first { store.prepare(firstChar: hiraFirst) }

    var results: [LookupResult] = []
    var seenTerms = Set<String>()
    for len in stride(from: s.count, through: 1, by: -1) {
        let sub = String(s[0..<len])
        let hira = toHiragana(sub)
        for q in uniqued([sub, hira]) {
            for c in Deinflector.deinflect(q) {
                if c.type == .te || c.type == .ta { continue }
                guard Deinflector.typeFits(c.term, c.type), !seenTerms.contains(c.term) else { continue }
                guard let entries = store.entries(c.term), !entries.isEmpty else { continue }
                seenTerms.insert(c.term)
                results.append(LookupResult(surface: sub, start: at, length: len, term: c.term,
                                            reasons: c.reasons, entries: entries))
            }
        }
    }
    // 길수록, 같은 길이면 활용 단계가 적을수록 앞
    return results.enumerated().sorted { a, b in
        if a.element.length != b.element.length { return a.element.length > b.element.length }
        if a.element.reasons.count != b.element.reasons.count { return a.element.reasons.count < b.element.reasons.count }
        return a.offset < b.offset
    }.map(\.element)
}

/// 검색창: 입력한 말을 활용형까지 풀어서 찾기
func lookupQuery(_ q: String, store: JaDictStore) -> [LookupResult] {
    let t = q.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCompatibilityMapping
    guard !t.isEmpty else { return [] }
    return lookupAt(t, at: 0, store: store, maxLen: 24)
}

/// 테스트·미리보기용 메모리 사전
final class MemoryJaDict: JaDictStore {
    var data: [String: [DictEntry]]
    init(_ data: [String: [DictEntry]]) { self.data = data }
    func prepare(firstChar: Character) {}
    func entries(_ key: String) -> [DictEntry]? { data[key] }
}
