import Foundation

/// 간격 반복: 맞히면 1·3·7·14·30·60일 뒤, 틀리면 10분 뒤. 시간은 ms(유닉스 기준).

let intervalDays = [1, 3, 7, 14, 30, 60]
let wrongDelayMs = 10 * 60 * 1000
private let dayMs = 24 * 60 * 60 * 1000

struct SrsState: Equatable {
    /// 연속으로 맞힌 횟수
    var stage: Int
    var dueAt: Int
}

func review(_ state: SrsState, correct: Bool, now: Int) -> SrsState {
    guard correct else { return SrsState(stage: 0, dueAt: now + wrongDelayMs) }
    let days = intervalDays[min(state.stage, intervalDays.count - 1)]
    return SrsState(stage: state.stage + 1, dueAt: now + days * dayMs)
}

func isDue(_ state: SrsState, now: Int) -> Bool {
    state.dueAt <= now
}

func describeDue(_ dueAt: Int, now: Int) -> String {
    let d = dueAt - now
    if d <= 0 { return "지금 복습" }
    if d < 60 * 60 * 1000 { return "\(Int((Double(d) / 60_000).rounded(.up)))분 뒤" }
    if d < dayMs { return "\(Int((Double(d) / 3_600_000).rounded()))시간 뒤" }
    return "\(Int((Double(d) / Double(dayMs)).rounded()))일 뒤"
}

func nowMs() -> Int {
    Int(Date().timeIntervalSince1970 * 1000)
}
