import Foundation

/// 네이버 영어사전(dict.naver.com) 검색 결과 → 앱의 사전 항목(Entry).
/// 엔드포인트와 응답 모양은 github.com/seia-soto/naverDict 와 같다:
///   GET https://en.dict.naver.com/api3/enko/search?query=<단어>&m=pc
///   searchResultMap.searchResultListMap.WORD.items[] 의 expEntry(표제어), meansCollector(품사별 뜻), searchPhoneticSymbolList(발음)
/// 응답 모양이 조금 바뀌어도 죽지 않도록, 모르는 칸은 건너뛴다.
enum NaverDictParser {
    /// 네이버 품사 → 앱 품사 코드 (posKorean 의 키)
    static let posMap: [String: String] = [
        "noun": "noun", "명사": "noun", "verb": "verb", "동사": "verb",
        "adjective": "adj", "형용사": "adj", "adverb": "adv", "부사": "adv",
        "pronoun": "pron", "대명사": "pron", "preposition": "prep", "전치사": "prep",
        "conjunction": "conj", "접속사": "conj", "determiner": "det", "한정사": "det",
        "interjection": "intj", "exclamation": "intj", "감탄사": "intj", "number": "num", "수사": "num",
        "article": "article", "관사": "article", "abbreviation": "abbrev", "약어": "abbrev",
        "prefix": "prefix", "접두사": "prefix", "suffix": "suffix", "접미사": "suffix",
        "phrasal verb": "verb", "구동사": "verb", "idiom": "phrase", "숙어": "phrase", "phrase": "phrase", "구": "phrase",
    ]

    /// JSON 응답 → 항목들. query 와 표제어가 같은 것을 앞에, 최대 maxItems 개 표제어.
    static func parse(_ data: Data, query: String, maxItems: Int = 4) -> [Entry] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let map = root["searchResultMap"] as? [String: Any],
              let lists = map["searchResultListMap"] as? [String: Any],
              let word = lists["WORD"] as? [String: Any],
              let items = word["items"] as? [[String: Any]] else { return [] }
        let q = normalizeWord(query.trimmingCharacters(in: .whitespacesAndNewlines))
        // 검색어와 똑같은 표제어를 먼저 (안정 정렬)
        let ordered = items.enumerated().sorted { a, b in
            let ea = headword(a.element).lowercased() == q, eb = headword(b.element).lowercased() == q
            return ea != eb ? ea : a.offset < b.offset
        }.map(\.element)

        var out: [Entry] = []
        var nextID = 0
        for item in ordered.prefix(maxItems) {
            let w = headword(item)
            guard !w.isEmpty else { continue }
            let ipa = phonetic(item)
            for group in (item["meansCollector"] as? [[String: Any]]) ?? [] {
                let posRaw = ((group["partOfSpeech2"] as? String) ?? (group["partOfSpeech"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespaces)
                let pos = posMap[posRaw.lowercased()] ?? posMap[posRaw] ?? (posRaw.isEmpty ? "noun" : posRaw)
                var means = (group["means"] as? [[String: Any]]) ?? []
                // 예전 응답: 뜻이 value 하나로 바로 들어 있음
                if means.isEmpty, let v = group["value"] { means = [["value": v]] }
                var senses: [Sense] = []
                for m in means {
                    let gloss = cleanHTML(stringValue(m["value"]))
                    guard !gloss.isEmpty else { continue }
                    var ex: [Example] = []
                    let exOri = cleanHTML(stringValue(m["exampleOri"]))
                    if !exOri.isEmpty {
                        let exKo = cleanHTML(stringValue(m["exampleTrans"]))
                        ex.append(Example(text: exOri, ko: exKo.isEmpty ? nil : exKo))
                    }
                    senses.append(Sense(id: senses.count, gloss: gloss, tags: tags(in: gloss), examples: ex))
                }
                guard !senses.isEmpty else { continue }
                out.append(Entry(id: nextID, word: w, pos: pos, source: .naver, senses: senses, ipa: ipa))
                nextID += 1
            }
        }
        return out
    }

    private static func headword(_ item: [String: Any]) -> String {
        for k in ["expEntry", "entryName", "handleEntry"] {
            let s = cleanHTML(stringValue(item[k]))
            if !s.isEmpty { return s }
        }
        return ""
    }

    /// 미국 발음 기호 우선
    private static func phonetic(_ item: [String: Any]) -> String? {
        let list = (item["searchPhoneticSymbolList"] as? [[String: Any]]) ?? []
        let us = list.first { ($0["symbolTypeCode"] as? String) == "US" || ($0["symbolType"] as? String) == "미국" } ?? list.first
        guard let p = us else { return nil }
        let v = cleanHTML(stringValue(p["symbolValue"] ?? p["phoneticSymbol"]))
        if v.isEmpty { return nil }
        return v.hasPrefix("[") ? v : "[\(v)]"
    }

    /// 뜻 앞의 (구어)·(속어) 같은 표시 → 앱 태그 (Tags.swift 가 한국어 배지로 보여 줌)
    private static func tags(in gloss: String) -> [String] {
        var t: [String] = []
        if gloss.contains("속어") { t.append("slang") }
        if gloss.contains("비격식") { t.append("informal") }
        if gloss.contains("구어") { t.append("colloquial") }
        if gloss.contains("격식") && !gloss.contains("비격식") { t.append("formal") }
        return t
    }

    private static func stringValue(_ v: Any?) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if let arr = v as? [Any] { return arr.map { stringValue($0) }.joined(separator: " ") }
        return ""
    }

    /// HTML 태그 지우기 + 엔티티 풀기 + 공백 정리
    static func cleanHTML(_ s: String) -> String {
        var t = s.replacingRegex("<[^>]+>", with: "")
        for (a, b) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&amp;", "&")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t.replacingRegex("\\s+", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 네이버 결과를 내장 사전 결과 위에 얹는다 (네이버 항목이 먼저, 내장 사전은 아래에 그대로)
func mergeNaver(_ local: LookupResult, word naverWord: [Entry], phrases naverPhrases: [String: [Entry]]) -> LookupResult {
    // 네이버 항목 id 는 음수로 다시 매겨서 내장 사전(양수 id)·다른 검색 결과와 겹치지 않게 (선택 키·목록 id)
    func renumber(_ list: [Entry], base: Int) -> [Entry] {
        list.enumerated().map { i, e in
            var e = e
            e.id = -(base + i + 1)
            return e
        }
    }
    var r = local
    r.entries = renumber(naverWord, base: 0) + local.entries
    r.phrases = local.phrases.enumerated().map { k, p in
        var p = p
        p.entries = renumber(naverPhrases[p.match.phrase.lowercased()] ?? [], base: 1000 * (k + 1)) + p.entries
        return p
    }
    if r.lemmas.isEmpty { r.lemmas = uniqued(naverWord.map { $0.word.lowercased() }) }
    return r
}
