import AVFoundation
import SwiftUI

/// 영어 단어·문장 소리 내서 읽기 (iOS 내장 음성, 인터넷·API 키 필요 없음)
@MainActor
final class Speech {
    static let shared = Speech()
    private let synth = AVSpeechSynthesizer()

    func say(_ text: String, slow: Bool = false) {
        let session = AVAudioSession.sharedInstance()
        // 무음 스위치를 켜 둬도 들리게, 영상 소리는 잠깐 작게
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.7 : 0.9)
        synth.speak(u)
    }
}

/// 스피커 버튼: 누르면 읽어 준다
struct SpeakButton: View {
    let text: String
    var label: String? = nil

    var body: some View {
        Button {
            Speech.shared.say(text, slow: !text.contains(" "))
        } label: {
            if let label {
                Label(label, systemImage: "speaker.wave.2.fill")
            } else {
                Image(systemName: "speaker.wave.2.fill")
                    .accessibilityLabel("\(text) 듣기")
            }
        }
        .buttonStyle(.borderless)
    }
}
