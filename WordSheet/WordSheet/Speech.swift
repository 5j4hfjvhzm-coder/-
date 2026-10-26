import AVFoundation
import NaturalLanguage

/// 단어 읽어주기. 단어장의 언어(영어, 독일어, 프랑스어 …)를 알아서 골라 읽어요.
@MainActor
final class Speech {
    static let shared = Speech()
    private let synth = AVSpeechSynthesizer()
    /// 단어장 id → 읽을 언어 코드
    private var languages: [String: String] = [:]

    func say(_ text: String, deck: Deck) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: language(for: deck))
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synth.speak(u)
    }

    /// 단어 하나로는 언어를 잘못 짐작하기 쉬워서, 단어장 전체 단어를 모아서 한 번 정해요.
    private func language(for deck: Deck) -> String {
        if let lang = languages[deck.id] { return lang }
        let sample = deck.entries.prefix(300).map(\.w).joined(separator: " ")
        let r = NLLanguageRecognizer()
        r.processString(sample)
        let code: String
        switch r.dominantLanguage?.rawValue {
        case nil, "en": code = "en-US"
        case "zh-Hans": code = "zh-CN"
        case "zh-Hant": code = "zh-TW"
        case let raw?: code = AVSpeechSynthesisVoice(language: raw) == nil ? "en-US" : raw
        }
        languages[deck.id] = code
        return code
    }
}
