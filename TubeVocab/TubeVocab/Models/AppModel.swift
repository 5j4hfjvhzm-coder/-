import Foundation
import Observation

enum AppTab: Hashable {
    case video, words, quiz
}

@MainActor
@Observable
final class AppModel {
    var tab: AppTab = .video
    let player = PlayerModel()
    let vocab = VocabStore()
    let dict: DictStore?
    let dictError: String?
    /// 열려 있는 사전 시트 (영상 위 자막, 아래 자막 카드 어디서 탭해도 같은 시트)
    var wordContext: WordContext?

    init() {
        do {
            dict = try SQLDictStore.bundled()
            dictError = nil
        } catch {
            dict = nil
            dictError = "사전을 열지 못했어요: \(error.localizedDescription)"
        }
    }

    /// 자막 단어 탭 → 영상 멈추고 사전 시트
    func openWord(cue: BiCue, tap: Int, words: [String]) {
        player.pause()
        wordContext = WordContext(
            words: words, tap: tap, sentenceEn: cue.en, sentenceKo: cue.ko,
            videoId: player.videoId ?? "", timeMs: player.timeMs
        )
    }

    /// 단어장에서 "영상에서 보기"
    func showInVideo(_ w: SavedWord) {
        player.open(w.videoId, startMs: max(0, w.timeMs - 1500))
        tab = .video
    }
}
