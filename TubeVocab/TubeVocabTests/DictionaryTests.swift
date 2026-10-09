import XCTest
@testable import TubeVocab

enum Fixtures {
    static func store() -> MemoryDictStore {
        var nextId = 1
        func e(_ word: String, _ pos: String, _ glosses: [(String, [String])], _ source: DictSource = .en) -> Entry {
            defer { nextId += 1 }
            return Entry(id: nextId, word: word, pos: pos, source: source,
                         senses: glosses.enumerated().map { i, g in Sense(id: nextId * 100 + i, gloss: g.0, tags: g.1) })
        }
        let entries = [
            e("go", "verb", [("To move from one place to another.", [])]),
            e("go", "noun", [("A turn at something.", [])]),
            e("go", "verb", [("가다", [])], .ko),
            e("give", "verb", [("To transfer the possession of something.", [])]),
            e("give up", "verb", [("To stop trying; to surrender.", ["idiomatic"])]),
            e("give up", "verb", [("포기하다", [])], .ko),
            e("pick", "verb", [("To choose.", [])]),
            e("pick up", "verb", [("To lift.", []), ("To learn informally.", ["informal"])]),
            e("up", "adv", [("Toward a higher place.", [])]),
            e("cool", "adj", [("Having a slightly low temperature.", []), ("Fashionable; excellent.", ["slang", "informal"])]),
            e("book", "noun", [("A collection of sheets of paper bound together.", [])]),
            e("book", "verb", [("To reserve.", [])]),
            e("see", "verb", [("To perceive with the eyes.", [])]),
            e("saw", "noun", [("A tool for cutting.", [])]),
            e("make up one's mind", "verb", [("To decide.", ["idiomatic"])]),
            e("look forward to", "verb", [("To anticipate with pleasure.", [])]),
            e("look", "verb", [("To try to see.", [])]),
        ]
        let forms = [
            FormRow(form: "went", lemma: "go", tags: "past"),
            FormRow(form: "goes", lemma: "go", tags: ""),
            FormRow(form: "gone", lemma: "go", tags: ""),
            FormRow(form: "gave", lemma: "give", tags: "past"),
            FormRow(form: "given", lemma: "give", tags: ""),
            FormRow(form: "saw", lemma: "see", tags: "past"),
            FormRow(form: "books", lemma: "book", tags: "plural"),
            FormRow(form: "made", lemma: "make", tags: "past"),
        ]
        return MemoryDictStore(entries: entries, forms: forms)
    }

    /// 문장에서 tapWord(n번째)를 탭한 것처럼 조회
    static func look(_ store: DictStore, _ sentence: String, _ tapWord: String) -> LookupResult {
        let ws = tokenize(sentence).filter(\.isWord).map(\.text)
        let tap = ws.firstIndex { $0.lowercased() == tapWord.lowercased() }!
        return lookupInContext(store, words: ws, tap: tap)
    }
}

final class LemmaTests: XCTestCase {
    func testRuleLemmas() {
        let cases = [
            ("books", "book"), ("watches", "watch"), ("studies", "study"), ("tried", "try"),
            ("liked", "like"), ("stopped", "stop"), ("running", "run"), ("making", "make"),
            ("lying", "lie"), ("bigger", "big"), ("happiest", "happy"), ("don't", "do"),
            ("won't", "will"), ("john's", "john"), ("don’t", "do"),
        ]
        for (w, lemma) in cases {
            let r = ruleLemmas(w)
            XCTAssertTrue(r.contains(lemma), "\(w) → \(r)")
            XCTAssertEqual(r.first, normalizeWord(w))
        }
    }
}

final class PhraseTests: XCTestCase {
    private func lem(_ toks: [String]) -> [[String]] {
        toks.map { ruleLemmas($0) + ($0 == "gave" ? ["give"] : []) + ($0 == "made" ? ["make"] : []) }
    }

    func testInflectedContiguous() {
        let toks = wordTokens("He gave up too early")
        let m = matchPhrases(tokens: toks, lemmas: lem(toks), tap: 1, phrases: ["give up", "give in"])
        XCTAssertEqual(m.map(\.phrase), ["give up"])
        XCTAssertEqual(m[0], PhraseMatch(phrase: "give up", start: 1, end: 2, literal: [1, 2], gapped: false))
    }

    func testSeparablePhrasalVerb() {
        let toks = wordTokens("Can you pick it up for me")
        let m = matchPhrases(tokens: toks, lemmas: lem(toks), tap: 4, phrases: ["pick up"])
        XCTAssertEqual(m.first, PhraseMatch(phrase: "pick up", start: 2, end: 4, literal: [2, 4], gapped: true))
    }

    func testTappingTheObjectIsNotThePhrase() {
        let toks = wordTokens("pick it up")
        XCTAssertEqual(matchPhrases(tokens: toks, lemmas: lem(toks), tap: 1, phrases: ["pick up"]), [])
    }

    func testPossessivePlaceholder() {
        let toks = wordTokens("She finally made up her mind")
        let m = matchPhrases(tokens: toks, lemmas: lem(toks), tap: 5, phrases: ["make up one's mind"])
        XCTAssertEqual(m.first?.start, 2)
        XCTAssertEqual(m.first?.end, 5)
        XCTAssertEqual(m.first?.literal, [2, 3, 5])
    }

    func testLongerPhraseFirst() {
        let toks = wordTokens("I look forward to it")
        let m = matchPhrases(tokens: toks, lemmas: lem(toks), tap: 1, phrases: ["look forward", "look forward to"])
        XCTAssertEqual(m.first?.phrase, "look forward to")
    }
}

final class PosTests: XCTestCase {
    func testGuessFromPreviousWord() {
        let cases: [(String, String, String)] = [
            ("a", "book", "noun"), ("to", "book", "verb"), ("will", "book", "verb"), ("I", "saw", "verb"),
            ("very", "cool", "adj"), ("is", "cool", "adj"), ("the", "saw", "noun"),
        ]
        for (prev, w, pos) in cases {
            XCTAssertEqual(guessPos(prev: prev, word: w).first, pos, "\(prev) \(w)")
        }
        XCTAssertEqual(guessPos(prev: nil, word: "quickly"), ["adv"])
    }

    func testTagLabels() {
        XCTAssertEqual(tagLabels(["informal", "slang", "transitive", "unknown-tag"]).map(\.label), ["속어", "비격식", "타동사"])
        XCTAssertTrue(tagLabels(["slang"])[0].strong)
    }
}

final class LookupTests: XCTestCase {
    let store = Fixtures.store()

    func testSeparablePhraseFoundWithOriginalSurface() {
        let r = Fixtures.look(store, "Never pick it up again", "up")
        XCTAssertEqual(r.phrases.first?.match.phrase, "pick up")
        XCTAssertEqual(r.phrases.first?.surface, "pick it up")
        XCTAssertFalse(r.phrases.first?.entries.isEmpty ?? true)
    }

    func testGaveUpFindsGiveUpInBothEditions() {
        let r = Fixtures.look(store, "She gave up.", "gave")
        XCTAssertEqual(r.phrases.map(\.match.phrase), ["give up"])
        XCTAssertEqual(Set(r.phrases[0].entries.map(\.source)), [.en, .ko])
        XCTAssertEqual(r.entries.first?.word, "give")
    }

    func testIrregularFormGoesToLemma() {
        let r = Fixtures.look(store, "We went home", "went")
        XCTAssertEqual(r.lemmas, ["go"])
        XCTAssertEqual(r.entries.first?.word, "go")
        XCTAssertEqual(r.entries.first?.pos, "verb")
        XCTAssertTrue(r.entries.contains { $0.source == .ko })
    }

    func testPosFromPreviousWordOrdersEntries() {
        XCTAssertEqual(Fixtures.look(store, "I read a book", "book").entries.first?.pos, "noun")
        XCTAssertEqual(Fixtures.look(store, "I need to book a room", "book").entries.first?.pos, "verb")
    }

    func testSawNounVsSee() {
        let noun = Fixtures.look(store, "Give me the saw", "saw").entries.first
        XCTAssertEqual(noun?.word, "saw")
        XCTAssertEqual(noun?.pos, "noun")
        let verb = Fixtures.look(store, "I saw it", "saw").entries.first
        XCTAssertEqual(verb?.word, "see")
    }

    func testSlangBadge() {
        let r = Fixtures.look(store, "That's so cool", "cool")
        let slang = r.entries[0].senses.first { $0.tags.contains("slang") }!
        XCTAssertEqual(tagLabels(slang.tags).map(\.label), ["속어", "비격식"])
    }

    func testUnknownWord() {
        let r = Fixtures.look(store, "blorpy things", "blorpy")
        XCTAssertTrue(r.entries.isEmpty)
        XCTAssertTrue(r.phrases.isEmpty)
    }

    func testDirectQuery() {
        XCTAssertEqual(lookupQuery(store, "went").entries.first?.word, "go")
        XCTAssertTrue(lookupQuery(store, "gave up").entries.map(\.word).contains("give up"))
        XCTAssertTrue(lookupQuery(store, "  ").entries.isEmpty)
    }
}
