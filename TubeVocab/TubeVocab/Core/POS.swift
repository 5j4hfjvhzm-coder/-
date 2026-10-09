import Foundation

/// 앞 단어로 탭한 단어의 품사를 대충 추정. 결과는 우선순위 순서의 wiktextract 품사 코드.

private let determiners: Set<String> = [
    "a", "an", "the", "this", "that", "these", "those", "my", "your", "his", "her", "its", "our",
    "their", "some", "any", "no", "every", "each", "another", "much", "many", "few", "several",
    "such", "what", "which", "someone's",
]
private let modals: Set<String> = [
    "can", "could", "will", "would", "shall", "should", "may", "might", "must", "do", "does", "did",
    "don't", "doesn't", "didn't", "won't", "can't", "cannot", "couldn't", "wouldn't", "shouldn't",
    "let's", "please", "i'll", "you'll", "we'll", "they'll", "i'd", "you'd", "gonna", "wanna",
]
private let subjects: Set<String> = ["i", "you", "we", "they", "he", "she", "who", "people"]
private let beVerbs: Set<String> = [
    "am", "is", "are", "was", "were", "be", "been", "being", "i'm", "you're", "we're", "they're",
    "he's", "she's", "it's", "that's", "seem", "seems", "seemed", "become", "became", "feel", "feels",
    "felt", "look", "looks", "looked", "sounds", "get", "got", "gets",
]
private let intensifiers: Set<String> = [
    "very", "so", "too", "really", "quite", "pretty", "extremely", "more", "most", "less", "least",
    "super", "totally", "kinda", "fairly", "rather",
]
private let prepositions: Set<String> = [
    "in", "on", "at", "of", "for", "with", "from", "by", "about", "into", "over", "under", "without",
    "through", "after", "before", "between", "during", "like", "against",
]

func guessPos(prev: String?, word: String) -> [String] {
    let w = word.lowercased()
    if let prev {
        let p = normalizeWord(prev)
        if determiners.contains(p) { return ["noun", "adj"] }
        if modals.contains(p) { return ["verb"] }
        if p == "to" { return ["verb", "noun"] }
        if subjects.contains(p) { return ["verb"] }
        if intensifiers.contains(p) { return ["adj", "adv"] }
        if beVerbs.contains(p) {
            return w.hasSuffix("ing") || w.hasSuffix("ed") ? ["verb", "adj"] : ["adj", "verb", "noun"]
        }
        if prepositions.contains(p) { return w.hasSuffix("ing") ? ["verb", "noun"] : ["noun"] }
    }
    if w.hasSuffix("ly") && w.count > 4 { return ["adv"] }
    return []
}

/// 품사 추정 점수: 낮을수록 위로
func posRank(_ pos: String, _ guess: [String]) -> Int {
    guess.firstIndex(of: pos) ?? guess.count + 1
}

let posKorean: [String: String] = [
    "noun": "명사", "verb": "동사", "adj": "형용사", "adv": "부사", "pron": "대명사",
    "prep": "전치사", "conj": "접속사", "det": "한정사", "intj": "감탄사", "num": "수사",
    "particle": "불변화사", "phrase": "구", "prep_phrase": "전치사구", "proverb": "속담",
    "contraction": "축약형", "article": "관사", "name": "고유명사", "prefix": "접두사",
    "suffix": "접미사", "abbrev": "약어",
]
