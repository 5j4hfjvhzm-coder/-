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

    init() {
        do {
            dict = try SQLDictStore.bundled()
            dictError = nil
        } catch {
            dict = nil
            dictError = "사전을 열지 못했어요: \(error.localizedDescription)"
        }
    }

    /// 단어장에서 "영상에서 보기"
    func showInVideo(_ w: SavedWord) {
        player.open(w.videoId, startMs: max(0, w.timeMs - 1500))
        tab = .video
    }
}
