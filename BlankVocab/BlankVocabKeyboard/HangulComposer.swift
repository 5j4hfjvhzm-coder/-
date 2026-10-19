import Foundation

/// 두벌식 한글 조합기.
/// 자모를 하나씩 넣으면 "확정된 글자"와 "조합 중인 글자(최대 1글자)"를 돌려준다.
struct HangulComposer {
    static let choseong: [Character] = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    static let jungseong: [Character] = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    /// 종성 (인덱스 + 1 이 유니코드 종성 번호, 0 은 받침 없음)
    static let jongseong: [Character] = Array("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ")

    static let vowelPairs: [String: Character] = [
        "ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ",
        "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ",
        "ㅡㅣ": "ㅢ",
    ]
    static let finalPairs: [String: Character] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ",
        "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ",
        "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ",
    ]

    static func isConsonant(_ c: Character) -> Bool { choseong.contains(c) }
    static func isVowel(_ c: Character) -> Bool { jungseong.contains(c) }
    static func isJamo(_ s: String) -> Bool {
        guard s.count == 1, let c = s.first else { return false }
        return isConsonant(c) || isVowel(c)
    }

    /// 지금 조합 중인 글자에 들어간 자모들 (지우기 할 때 다시 조합하는 데 씀)
    private var inputs: [Character] = []
    private var cho: Character?
    private var jung: Character?
    private var jong: Character?

    var composing: String {
        if let cho, let jung,
           let ci = Self.choseong.firstIndex(of: cho),
           let vi = Self.jungseong.firstIndex(of: jung) {
            let fi = jong.flatMap { Self.jongseong.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
            let code = 0xAC00 + (ci * 21 + vi) * 28 + fi
            return UnicodeScalar(code).map { String(Character($0)) } ?? ""
        }
        if let cho { return String(cho) }
        if let jung { return String(jung) }
        return ""
    }

    var isEmpty: Bool { inputs.isEmpty }

    mutating func reset() {
        inputs = []
        cho = nil
        jung = nil
        jong = nil
    }

    mutating func input(_ c: Character) -> (commit: String, composing: String) {
        Self.isVowel(c) ? addVowel(c) : addConsonant(c)
    }

    /// 자모 하나를 지우고 남은 조합 글자를 돌려준다.
    mutating func backspace() -> String {
        guard !inputs.isEmpty else { return "" }
        inputs.removeLast()
        recompose()
        return composing
    }

    // MARK: - 내부

    private mutating func addConsonant(_ k: Character) -> (commit: String, composing: String) {
        if cho == nil && jung == nil {
            cho = k
            inputs.append(k)
            return ("", composing)
        }
        if jung == nil {
            // 초성만 있는 상태 → 확정하고 새 글자
            return commitAndStart([k])
        }
        if jong == nil {
            if cho != nil, Self.jongseong.contains(k) {
                jong = k
                inputs.append(k)
                return ("", composing)
            }
            return commitAndStart([k])
        }
        if let f = jong, let combined = Self.finalPairs[String(f) + String(k)] {
            jong = combined
            inputs.append(k)
            return ("", composing)
        }
        return commitAndStart([k])
    }

    private mutating func addVowel(_ v: Character) -> (commit: String, composing: String) {
        if jung == nil {
            // 빈 상태 또는 초성만 있는 상태
            jung = v
            inputs.append(v)
            return ("", composing)
        }
        if jong == nil {
            if let last = inputs.last, Self.isVowel(last), let current = jung,
               let combined = Self.vowelPairs[String(current) + String(v)] {
                jung = combined
                inputs.append(v)
                return ("", composing)
            }
            return commitAndStart([v])
        }
        // 받침이 있는 상태에서 모음 → 마지막 자음을 다음 글자의 초성으로 넘긴다 (갈+ㅏ → 가라, 갉+ㅏ → 갈가)
        let moved = inputs.removeLast()
        recompose()
        return commitAndStart([moved, v])
    }

    private mutating func commitAndStart(_ chars: [Character]) -> (commit: String, composing: String) {
        let out = composing
        reset()
        for c in chars { _ = input(c) }
        return (out, composing)
    }

    private mutating func recompose() {
        let saved = inputs
        reset()
        for c in saved { _ = input(c) }
    }
}
