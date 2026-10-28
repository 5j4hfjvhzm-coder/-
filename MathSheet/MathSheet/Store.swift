import Combine
import Foundation

struct UnitStat: Identifiable {
    let unit: MathUnit
    let right: Int
    let total: Int
    var id: MathUnit { unit }
}

/// 학습지를 기기에 저장해요 (Documents/mathsheet.json).
/// 앱을 열 때마다 지난번 이후 날짜의 학습지를 만들어서, 안 풀면 차곡차곡 쌓여요.
@MainActor
final class Store: ObservableObject {
    private struct SaveData: Codable {
        var sheets: [Worksheet]
        var settings: Settings
        /// 마지막으로 학습지를 만든 날
        var lastDay: String?
    }

    @Published private(set) var sheets: [Worksheet] = []
    @Published var settings = Settings() {
        didSet {
            guard settings != oldValue else { return }
            if settings.units.isEmpty { settings.units = oldValue.units }
            if settings.problemsPerDay != oldValue.problemsPerDay || settings.units != oldValue.units {
                // 아직 한 문제도 안 건드린 학습지는 새 설정으로 다시 만들어요.
                for i in sheets.indices where !sheets[i].isDone && sheets[i].answeredCount == 0 {
                    sheets[i].problems = Generator.worksheet(day: sheets[i].id, settings: settings)
                }
            }
            save()
            if settings.reminderOn != oldValue.reminderOn || settings.reminderMinutes != oldValue.reminderMinutes {
                updateReminder()
            }
        }
    }
    private var lastDay: String?

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("mathsheet.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data) {
            sheets = saved.sheets
            settings = saved.settings
            lastDay = saved.lastDay
        }
        refresh()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(SaveData(sheets: sheets, settings: settings, lastDay: lastDay))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("저장 실패: \(error)")
        }
        Reminder.setBadge(pending.count)
    }

    // MARK: - 학습지 만들기

    /// 지난번에 만든 날 다음 날부터 오늘까지 학습지를 만들어요.
    func refresh() {
        let today = Day.today
        var day = lastDay.map(Day.next) ?? today
        var changed = false
        while day <= today {
            if !(settings.skipWeekends && Day.isWeekend(day)) && !sheets.contains(where: { $0.id == day }) {
                sheets.append(Worksheet(id: day, problems: Generator.worksheet(day: day, settings: settings)))
                changed = true
            }
            day = Day.next(day)
        }
        if lastDay != today {
            lastDay = today
            changed = true
        }
        sheets.sort { $0.id < $1.id }
        if changed { save() } else { Reminder.setBadge(pending.count) }
    }

    // MARK: - 목록

    /// 아직 안 푼 학습지 (오래된 것부터)
    var pending: [Worksheet] { sheets.filter { !$0.isDone } }

    var todaySheet: Worksheet? { sheets.first { $0.id == Day.today } }

    /// 밀린 학습지 (오늘 것 빼고)
    var overdue: [Worksheet] { pending.filter { $0.id != Day.today } }

    /// 다 푼 학습지 (최근 것부터)
    var done: [Worksheet] { sheets.filter(\.isDone).sorted { ($0.submittedAt ?? .distantPast) > ($1.submittedAt ?? .distantPast) } }

    func sheet(_ id: String) -> Worksheet? { sheets.first { $0.id == id } }

    /// 학습지를 낸 날이 며칠 연속인지 (오늘 아직 안 냈으면 어제까지 세요)
    var streak: Int {
        let days = Set(sheets.compactMap { $0.submittedAt.map(Day.key) })
        var day = Day.today
        if !days.contains(day) { day = Day.previous(day) }
        var n = 0
        while days.contains(day) {
            n += 1
            day = Day.previous(day)
        }
        return n
    }

    var totalSolved: Int { sheets.filter(\.isDone).reduce(0) { $0 + $1.problems.count } }
    var totalCorrect: Int { sheets.filter(\.isDone).reduce(0) { $0 + $1.score } }

    /// 단원별 정답률 (푼 문제가 있는 단원만)
    var unitStats: [UnitStat] {
        let problems = sheets.filter(\.isDone).flatMap(\.problems)
        return MathUnit.allCases.compactMap { u in
            let ps = problems.filter { $0.unit == u }
            return ps.isEmpty ? nil : UnitStat(unit: u, right: ps.filter { $0.correct == true }.count, total: ps.count)
        }
    }

    // MARK: - 풀기

    func setAnswer(_ text: String, problem: String, sheet: String) {
        guard let s = sheets.firstIndex(where: { $0.id == sheet }), !sheets[s].isDone,
              let p = sheets[s].problems.firstIndex(where: { $0.id == problem }),
              sheets[s].problems[p].userAnswer != text else { return }
        sheets[s].problems[p].userAnswer = text
        save()
    }

    func submit(_ sheet: String) {
        guard let s = sheets.firstIndex(where: { $0.id == sheet }), !sheets[s].isDone else { return }
        for i in sheets[s].problems.indices {
            let p = sheets[s].problems[i]
            sheets[s].problems[i].correct = p.isCorrect(p.userAnswer)
        }
        sheets[s].submittedAt = Date()
        save()
    }

    /// 다 푼 학습지에서 틀린 문제만 새 답으로 다시 확인 (점수는 처음 그대로)
    func retryCheck(_ text: String, problem: String, sheet: String) -> Bool {
        guard let s = sheets.firstIndex(where: { $0.id == sheet }),
              let p = sheets[s].problems.firstIndex(where: { $0.id == problem }) else { return false }
        return sheets[s].problems[p].isCorrect(text)
    }

    // MARK: - 설정

    /// 모든 기록을 지우고 오늘부터 다시 시작
    func resetAll() {
        sheets = []
        lastDay = nil
        refresh()
        save()
    }

    func updateReminder() {
        let on = settings.reminderOn
        let minutes = settings.reminderMinutes
        Task {
            if on {
                let ok = await Reminder.schedule(hour: minutes / 60, minute: minutes % 60)
                if !ok { settings.reminderOn = false }
            } else {
                Reminder.cancel()
            }
        }
    }
}
