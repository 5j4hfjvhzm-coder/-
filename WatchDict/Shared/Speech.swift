import AVFoundation

/// 단어 발음 듣기. 한글이 있으면 한국어, 아니면 미국 영어로 읽어요.
@MainActor
final class Speech {
    static let shared = Speech()
    private let synth = AVSpeechSynthesizer()

    func say(_ text: String) {
        #if os(iOS)
        // 무음 모드에서도 들리게
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: Self.hasHangul(text) ? "ko-KR" : "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synth.speak(u)
    }

    static func hasHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x318E).contains($0.value) }
    }
}
