import AVFoundation

/// 영어 문제 읽어주기
@MainActor
final class Speech {
    static let shared = Speech()
    private let synth = AVSpeechSynthesizer()

    func say(_ problem: Problem) {
        var text = problem.text
        if let e = problem.expr { text += " " + e }
        if let c = problem.choices { text += " " + c.joined(separator: ", ") + "." }
        say(text)
    }

    func say(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: spoken(text))
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synth.speak(u)
    }

    /// 분수를 날짜(2/3 → February 3rd)로 읽지 않게 바꿔요.
    private func spoken(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: #"(\d+) (\d+)/(\d+)"#, with: "$1 and $2 over $3", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(\d+)/(\d+)"#, with: "$1 over $2", options: .regularExpression)
        s = s.replacingOccurrences(of: "×", with: " times ")
        s = s.replacingOccurrences(of: "÷", with: " divided by ")
        s = s.replacingOccurrences(of: "−", with: " minus ")
        s = s.replacingOccurrences(of: "m²", with: " square meters")
        s = s.replacingOccurrences(of: "°", with: " degrees")
        return s
    }
}
