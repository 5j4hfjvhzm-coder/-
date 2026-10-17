import Foundation
import Observation

enum AppTab: Hashable {
    case video, words, quiz
}

/// 사전 시트에 넘길 문맥: 어느 문장의 몇 번째 글자를 눌렀는지
struct WordContext: Identifiable {
    let id = UUID()
    let sentence: String
    let sentenceKo: String
    /// 누른 글자 위치
    let at: Int
    let videoId: String
    let timeMs: Int
}

@MainActor
@Observable
final class AppModel {
    var tab: AppTab = .video
    let player = PlayerModel()
    let vocab = VocabStore()
    let quiz = QuizModel()
    /// 아이폰·맥 단어장 동기화 (iCloud Drive 폴더)
    let sync: SyncService
    let dict: JaDictStore?
    let dictError: String?
    /// 열려 있는 사전 시트 (영상 위 자막, 아래 자막 카드 어디서 탭해도 같은 시트)
    var wordContext: WordContext?

    init() {
        sync = SyncService(vocab: vocab)
        do {
            dict = try JaDictDB.bundled()
            dictError = nil
        } catch {
            dict = nil
            dictError = "사전을 열지 못했어요: \(error.localizedDescription)"
        }
    }

    /// 자막 단어 탭 → 영상 멈추고 사전 시트
    func openWord(cue: BiCue, at: Int) {
        player.pause()
        wordContext = WordContext(sentence: cue.ja, sentenceKo: cue.ko, at: at,
                                  videoId: player.videoId ?? "", timeMs: cue.start)
    }

    /// 단어장에서 "영상에서 보기"
    func showInVideo(_ w: SavedWord) {
        player.open(w.videoId, startMs: max(0, w.timeMs - 1500))
        tab = .video
    }
}
