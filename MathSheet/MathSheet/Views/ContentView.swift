import SwiftUI

enum Route: Hashable {
    case sheet(String)
    case history
    case wrongNotes
    case practice
}

extension MathUnit {
    var color: Color {
        switch self {
        case .range: return .blue
        case .fractionMul: return .orange
        case .symmetry: return .purple
        case .decimalMul: return .teal
        case .cuboid: return .green
        case .average: return .pink
        }
    }
}

/// 아이패드: 왼쪽은 학습지 목록, 오른쪽은 고른 학습지
struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var selection: Route?
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section { summary }

                if store.settings.studyMode == .chapter { chapterBanner }

                Section {
                    if store.todaySheets.isEmpty {
                        Label("오늘은 쉬는 날이에요 🎉", systemImage: "sun.max")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.todaySheets) { sheet in
                        NavigationLink(value: Route.sheet(sheet.id)) {
                            SheetRow(sheet: sheet, highlight: true)
                        }
                    }
                } header: {
                    let all = store.todaySheets
                    Text("오늘의 학습지 · \(all.filter(\.isDone).count)/\(all.count)장 완료")
                }

                if !store.overdue.isEmpty {
                    Section {
                        ForEach(store.overdue) { sheet in
                            NavigationLink(value: Route.sheet(sheet.id)) {
                                SheetRow(sheet: sheet, highlight: false)
                            }
                        }
                    } header: {
                        Text("밀린 학습지 \(store.overdue.count)장")
                    } footer: {
                        Text("안 푼 학습지는 매일 하나씩 쌓여요. 오래된 것부터 풀어 봐요!")
                    }
                }

                Section {
                    NavigationLink(value: Route.practice) {
                        Label("단원별 연습 · 원하는 단원 풀기", systemImage: "square.grid.2x2")
                    }
                    NavigationLink(value: Route.wrongNotes) {
                        Label("오답노트 · 틀린 문제 \(store.wrongProblems.count)개", systemImage: "exclamationmark.bubble")
                    }
                    NavigationLink(value: Route.history) {
                        Label("기록 · 다 푼 학습지 \(store.done.count)장", systemImage: "chart.bar.doc.horizontal")
                    }
                }
            }
            .navigationTitle("매일 수학")
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 400)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
        } detail: {
            NavigationStack {
                switch selection {
                case .sheet(let id):
                    WorksheetView(sheetID: id, selection: $selection)
                        .id(id)
                case .history:
                    HistoryView(selection: $selection)
                case .practice:
                    PracticeView(selection: $selection)
                case .wrongNotes:
                    WrongNotesView()
                case nil:
                    welcome
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(store)
        }
        .onAppear {
            // 처음엔 가장 오래된 안 푼 학습지(없으면 오늘 것)를 열어 둬요.
            if selection == nil, let first = store.pending.first ?? store.todaySheets.first {
                selection = .sheet(first.id)
            }
        }
    }

    private var welcome: some View {
        ContentUnavailableView {
            Label("학습지를 골라 주세요", systemImage: "doc.text")
        } description: {
            Text(store.pending.isEmpty ? "밀린 학습지가 없어요. 내일 또 만나요! 👋" : "남은 학습지 \(store.pending.count)장")
        }
    }

    /// 이번 단원과 기간
    private var chapterBanner: some View {
        let today = Day.today
        let unit = store.settings.unit(on: today)
        let period = store.settings.period(on: today)
        let left = Day.days(from: today, to: period.end) + 1
        let next = store.settings.unit(on: Day.next(period.end))
        return Section {
            HStack(spacing: 12) {
                Text("\(unit.number)")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(unit.color))
                VStack(alignment: .leading, spacing: 3) {
                    Text(unit.korean).font(.headline)
                    Text("\(Day.short(period.start)) ~ \(Day.short(period.end)) · \(left)일 남음")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("다음 단원: \(next.number). \(next.korean)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("이번 단원 (반복 학습)")
        }
    }

    private var summary: some View {
        HStack(spacing: 0) {
            stat("\(store.pending.count)", "남은 학습지", store.pending.count > 3 ? .red : .orange)
            Divider()
            stat("\(store.streak)일", "🔥 연속", .orange)
            Divider()
            stat(store.totalSolved == 0 ? "–" : "\(store.totalCorrect * 100 / store.totalSolved)%", "정답률", .green)
        }
        .padding(.vertical, 6)
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SheetRow: View {
    let sheet: Worksheet
    let highlight: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sheet.isDone ? "checkmark.seal.fill" : "doc.text.fill")
                .font(.title2)
                .foregroundStyle(sheet.isDone ? .green : (highlight ? .orange : .secondary))
            VStack(alignment: .leading, spacing: 3) {
                Text(sheet.title).font(.headline)
                HStack(spacing: 4) {
                    ForEach(Array(Set(sheet.problems.map(\.unit))).sorted { $0.number < $1.number }) { u in
                        Circle().fill(u.color).frame(width: 7, height: 7)
                    }
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if sheet.isDone {
                Text("\(sheet.score)/\(sheet.problems.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.green)
            } else if !highlight {
                let ago = Day.daysAgo(sheet.dayKey)
                Text("\(ago)일 전")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill((ago >= 3 ? Color.red : Color.orange).opacity(0.15)))
                    .foregroundStyle(ago >= 3 ? .red : .orange)
            }
        }
        .padding(.vertical, 4)
    }

    private var detail: String {
        if sheet.isDone { return "다 풀었어요" }
        let a = sheet.answeredCount
        return a == 0 ? "\(sheet.problems.count)문제" : "\(sheet.problems.count)문제 중 \(a)개 풀었어요"
    }
}
