import AVFoundation

/// 영어 문장 읽기 (웹 버전의 speechSynthesis 대신 AVSpeechSynthesizer 사용)
@MainActor
final class Speech {
    static let shared = Speech()
    private let synth = AVSpeechSynthesizer()

    /// 설정의 "읽기 속도" (UserDefaults "speechSpeed")
    enum Speed: Double, CaseIterable, Identifiable {
        case slow = 0.7, normal = 0.9, native = 1.05

        var id: Double { rawValue }
        var name: String {
            switch self {
            case .slow: return "듣기평가 속도"
            case .normal: return "보통"
            case .native: return "실전(원어민) 속도"
            }
        }

        static var current: Speed {
            Speed(rawValue: UserDefaults.standard.double(forKey: "speechSpeed")) ?? .normal
        }
    }

    static func utterance(_ text: String) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = min(AVSpeechUtteranceDefaultSpeechRate * Float(Speed.current.rawValue), AVSpeechUtteranceMaximumSpeechRate)
        return u
    }

    static func activatePlayback() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func say(_ text: String) {
        Speech.activatePlayback()
        synth.stopSpeaking(at: .immediate)
        synth.speak(Speech.utterance(text))
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}
