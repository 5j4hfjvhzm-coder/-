import SwiftUI

enum Route: Hashable {
    case sheet(String)
    case history
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

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var path: [Route] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section { summary }

                Section("오늘의 학습지") {
                    if let today = store.todaySheet {
                        NavigationLink(value: Route.sheet(today.id)) {
                            SheetRow(sheet: today, highlight: true)
                        }
                    } else {
                        Label("오늘은 쉬는 날이에요 🎉", systemImage: "sun.max")
                            .foregroundStyle(.secondary)
                    }
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
                    NavigationLink(value: Route.history) {
                        Label("기록 · 다 푼 학습지 \(store.done.count)장", systemImage: "chart.bar.doc.horizontal")
                    }
                }
            }
            .navigationTitle("매일 수학")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .sheet(let id): WorksheetView(sheetID: id, path: $path)
                case .history: HistoryView()
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(store)
            }
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
                Text(Day.label(sheet.id)).font(.headline)
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
                let ago = Day.daysAgo(sheet.id)
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
