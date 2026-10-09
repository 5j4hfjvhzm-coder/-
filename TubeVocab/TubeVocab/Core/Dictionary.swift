import Foundation

/// 사전 조회 로직. 저장소(SQLite 등)는 DictStore 프로토콜 뒤에 숨겨서 테스트에서 메모리 구현을 쓴다.

struct Example: Hashable {
    var text: String
    /// 예문 번역 (한국어판)
    var ko: String? = nil
}

struct Sense: Hashable, Identifiable {
    var id: Int
    var gloss: String
    var tags: [String]
    var examples: [Example] = []
    /// 영어판 번역란의 한국어 단어
    var ko: [String] = []
}

enum DictSource: String, Hashable {
    /// 영어판(영영)
    case en
    /// 한국어판(영한)
    case ko
}

struct Entry: Hashable, Identifiable {
    var id: Int
    var word: String
    var pos: String
    var source: DictSource
    var senses: [Sense]
    var ipa: String? = nil
    /// 뜻에 연결되지 않은 한국어 번역
    var ko: [String] = []
}

struct FormRow: Equatable {
    var form: String
    var lemma: String
    var tags: String
}

protocol DictStore: AnyObject {
    /// 활용형 → 기본형 (forms 표)
    func lemmasOf(_ forms: [String]) -> [FormRow]
    /// 기본형 → 활용형
    func formsOf(_ lemma: String) -> [String]
    /// 표제어(소문자)로 항목
    func entriesFor(_ words: [String]) -> [Entry]
    /// 여러 단어 표제어 중 첫 단어가 firsts 안에 있는 것
    func phrasesStartingWith(_ firsts: [String]) -> [String]
    /// 직접 검색용 접두어 검색
    func searchPrefix(_ prefix: String, limit: Int) -> [String]
}

struct PhraseResult: Identifiable, Hashable {
    var id: String { match.phrase }
    var match: PhraseMatch
    /// 문장에서 맞은 부분 그대로 (예: "pick it up")
    var surface: String
    var entries: [Entry]
}

struct LookupResult: Hashable {
    var surface: String
    /// 사전에 실제로 있는 기본형들
    var lemmas: [String]
    var guessedPos: [String]
    var phrases: [PhraseResult]
    var entries: [Entry]

    static let empty = LookupResult(surface: "", lemmas: [], guessedPos: [], phrases: [], entries: [])
}

/// 각 토큰의 기본형 후보 (자기 자신 + forms 표 + 규칙)
func lemmaCandidates(_ store: DictStore, _ toks: [String]) -> [[String]] {
    var byForm: [String: [String]] = [:]
    for r in store.lemmasOf(uniqued(toks)) {
        byForm[r.form, default: []].append(r.lemma)
    }
    // DB 기본형을 규칙 후보보다 앞에 (went → go)
    return toks.map { t in uniqued([t] + (byForm[t] ?? []) + Array(ruleLemmas(t).dropFirst())) }
}

func rankEntries(_ entries: [Entry], guess: [String], prefer: [String]) -> [Entry] {
    func wordRank(_ w: String) -> Int { prefer.firstIndex(of: w.lowercased()) ?? prefer.count }
    return entries.enumerated().sorted { a, b in
        let x = a.element, y = b.element
        let pa = posRank(x.pos, guess), pb = posRank(y.pos, guess)
        if pa != pb { return pa < pb }
        let wa = wordRank(x.word), wb = wordRank(y.word)
        if wa != wb { return wa < wb }
        // 같은 품사면 한국어판(영한)을 위로
        if x.source != y.source { return x.source == .ko }
        return a.offset < b.offset
    }.map(\.element)
}

/// 문장 속 단어 조회.
/// - Parameters:
///   - sentenceWords: 문장의 단어 토큰(원문 그대로)
///   - tap: 탭한 단어 인덱스
func lookupInContext(_ store: DictStore, words sentenceWords: [String], tap: Int) -> LookupResult {
    guard tap >= 0, tap < sentenceWords.count else { return .empty }
    let toks = sentenceWords.map(normalizeWord)
    // 앞뒤 2~5단어 창에서만 숙어 후보를 본다
    let lo = max(0, tap - 5)
    let hi = min(toks.count, tap + 6)
    let winToks = Array(toks[lo..<hi])
    let winLemmas = lemmaCandidates(store, winToks)
    let tapLocal = tap - lo

    // 1) 숙어·구동사
    let firsts = uniqued(winLemmas[0...tapLocal].flatMap { $0 })
    let candidates = store.phrasesStartingWith(firsts)
    let matches = matchPhrases(tokens: winToks, lemmas: winLemmas, tap: tapLocal, phrases: candidates)
    let phraseEntries = matches.isEmpty ? [] : store.entriesFor(matches.map { $0.phrase.lowercased() })
    let phrases: [PhraseResult] = matches.compactMap { m in
        var g = m
        g.start += lo
        g.end += lo
        g.literal = m.literal.map { $0 + lo }
        let es = phraseEntries.filter { $0.word.lowercased() == m.phrase.lowercased() }
        guard !es.isEmpty else { return nil }
        return PhraseResult(match: g, surface: sentenceWords[g.start...g.end].joined(separator: " "), entries: es)
    }

    // 2) 단어 자체 + 기본형
    let cands = winLemmas[tapLocal]
    let entries = store.entriesFor(cands)
    let found = cands.filter { c in entries.contains { $0.word.lowercased() == c } }
    let guess = guessPos(prev: tap > 0 ? toks[tap - 1] : nil, word: toks[tap])
    // 활용형이면 기본형 항목을 표면형 항목보다 위로 (went 의 "go")
    let dbLemmas = cands.dropFirst().filter { found.contains($0) }
    return LookupResult(
        surface: sentenceWords[tap],
        lemmas: found,
        guessedPos: guess,
        phrases: phrases,
        entries: rankEntries(entries, guess: guess, prefer: Array(dbLemmas) + [toks[tap]])
    )
}

/// 단어장 탭의 직접 검색
func lookupQuery(_ store: DictStore, _ query: String) -> LookupResult {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let q = normalizeWord(trimmed.replacingRegex("\\s+", with: " "))
    if q.isEmpty { return .empty }
    if q.contains(" ") {
        var entries = store.entriesFor([q])
        let ws = q.split(separator: " ").map(String.init)
        let lemmas = lemmaCandidates(store, ws)
        // "gave up" 처럼 활용형으로 쳐도 찾기
        let cands = phraseFirstToken(q) != nil ? store.phrasesStartingWith(lemmas[0]) : []
        let m = matchPhrases(tokens: ws, lemmas: lemmas, tap: 0, phrases: cands)
        if !m.isEmpty { entries += store.entriesFor(m.map { $0.phrase.lowercased() }) }
        var seen = Set<String>()
        let all = entries.filter { seen.insert("\($0.source.rawValue):\($0.id)").inserted }
        return LookupResult(surface: trimmed, lemmas: uniqued(all.map(\.word)), guessedPos: [], phrases: [], entries: all)
    }
    let cands = lemmaCandidates(store, [q])[0]
    let entries = store.entriesFor(cands)
    return LookupResult(
        surface: trimmed,
        lemmas: cands.filter { c in entries.contains { $0.word.lowercased() == c } },
        guessedPos: [],
        phrases: [],
        entries: rankEntries(entries, guess: [], prefer: [q] + cands.dropFirst())
    )
}

/// 메모리 구현 (테스트·미리보기용)
final class MemoryDictStore: DictStore {
    private let entries: [Entry]
    private let forms: [FormRow]

    init(entries: [Entry], forms: [FormRow]) {
        self.entries = entries
        self.forms = forms
    }

    func lemmasOf(_ forms: [String]) -> [FormRow] {
        let set = Set(forms)
        return self.forms.filter { set.contains($0.form) }
    }

    func formsOf(_ lemma: String) -> [String] {
        uniqued(forms.filter { $0.lemma == lemma }.map(\.form))
    }

    func entriesFor(_ words: [String]) -> [Entry] {
        let set = Set(words)
        return entries.filter { set.contains($0.word.lowercased()) }
    }

    func phrasesStartingWith(_ firsts: [String]) -> [String] {
        let set = Set(firsts)
        return uniqued(entries.filter { $0.word.contains(" ") && set.contains(phraseFirstToken($0.word) ?? "") }.map { $0.word.lowercased() })
    }

    func searchPrefix(_ prefix: String, limit: Int) -> [String] {
        let p = prefix.lowercased()
        return Array(Set(entries.map { $0.word.lowercased() }).filter { $0.hasPrefix(p) }.sorted().prefix(limit))
    }
}
