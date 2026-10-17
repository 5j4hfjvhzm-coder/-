import Foundation
@testable import NihongoTube

/// 테스트용 작은 사전
func fixtureDict() -> MemoryJaDict {
    func e(_ r: String, _ ko: String) -> DictEntry { DictEntry(reading: r, ko: ko, def: "") }
    return MemoryJaDict([
        "食べる": [e("たべる", "먹다")], "たべる": [e("", "먹다")],
        "行く": [e("いく", "가다")], "行う": [e("おこなう", "행하다")],
        "待つ": [e("まつ", "기다리다")], "忘れる": [e("わすれる", "잊다")],
        "楽しい": [e("たのしい", "즐겁다")], "高い": [e("たかい", "높다")],
        "勉強する": [e("べんきょうする", "공부하다")], "勉強": [e("べんきょう", "공부")],
        "来る": [e("くる", "오다")], "話す": [e("はなす", "말하다")],
        "今日": [e("きょう", "오늘")], "今": [e("いま", "지금")],
        "読む": [e("よむ", "읽다")], "書く": [e("かく", "쓰다")],
        "日本語": [e("にほんご", "일본어")], "日本": [e("にほん", "일본")],
        "コーヒー": [e("", "커피")],
    ])
}

func makeWord(_ surface: String, term: String, readings: [String] = [], sentence: String? = nil,
              star: Bool = false, id: UUID = UUID(), created: Int = nowMs()) -> SavedWord {
    var w = SavedWord(id: id, surface: surface, term: term, reading: readings.first ?? "", readings: readings,
                      meanings: [Meaning(ko: "뜻", def: "", reading: readings.first ?? "")],
                      sentence: sentence ?? "昨日\(surface)。", sentenceKo: "어제.", start: sentence == nil ? 2 : 0,
                      videoId: "v", timeMs: 0, createdAt: created)
    w.starred = star
    return w
}
