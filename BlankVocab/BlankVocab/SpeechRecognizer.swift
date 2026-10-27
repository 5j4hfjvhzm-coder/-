import AVFoundation
import Observation
import Speech

/// 마이크로 영어 말하기를 받아 글자로 바꿔요 (스피킹 연습용).
@MainActor
@Observable
final class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var error: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func start() async {
        guard !isRecording else { return }
        error = nil
        transcript = ""

        let auth = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard auth == .authorized else {
            error = "음성 인식 권한이 필요해요. 설정 › 빈칸 단어장에서 '음성 인식'을 켜 주세요."
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            error = "마이크 권한이 필요해요. 설정 › 빈칸 단어장에서 '마이크'를 켜 주세요."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            error = "지금은 음성 인식을 쓸 수 없어요. 인터넷 연결을 확인해 주세요."
            return
        }

        do {
            Speech.shared.stop()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            request = req
            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0), block: Self.tapBlock(req))
            engine.prepare()
            try engine.start()

            isRecording = true
            task = recognizer.recognitionTask(with: req, resultHandler: Self.resultHandler(self))
        } catch {
            self.error = "녹음을 시작하지 못했어요."
            stop()
        }
    }

    func stop() {
        guard isRecording || request != nil else { return }
        isRecording = false
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task = nil
        Speech.activatePlayback()
    }

    // 오디오 스레드에서 불리는 콜백은 메인 액터 밖에서 만들어요.
    nonisolated private static func tapBlock(_ req: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in req.append(buffer) }
    }

    nonisolated private static func resultHandler(_ owner: SpeechRecognizer) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak owner] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                guard let owner else { return }
                if let text { owner.transcript = text }
                if final || failed { owner.stop() }
            }
        }
    }

    /// 말한 문장이 목표 문장과 얼마나 같은지 (단어 순서까지 고려, 0~100)
    static func score(said: String, target: String) -> Int {
        let a = words(target), b = words(said)
        guard !a.isEmpty else { return 0 }
        // 가장 긴 공통 부분 수열(LCS)로 순서대로 맞힌 단어 수를 세요.
        var dp = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 1...a.count {
            for j in stride(from: 1, through: b.count, by: 1) {
                dp[i][j] = a[i - 1] == b[j - 1] ? dp[i - 1][j - 1] + 1 : max(dp[i - 1][j], dp[i][j - 1])
            }
        }
        let matched = dp[a.count][b.count]
        let precision = b.isEmpty ? 0 : Double(matched) / Double(b.count)
        let recall = Double(matched) / Double(a.count)
        return Int((recall * 0.8 + precision * 0.2) * 100)
    }

    static func words(_ s: String) -> [String] {
        Blank.normalize(s)
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
    }
}
