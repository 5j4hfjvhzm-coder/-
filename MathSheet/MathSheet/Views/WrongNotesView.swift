import SwiftUI

/// 오답노트: 다 푼 학습지에서 틀린 문제만 모아 풀이와 함께 보여줘요. 다시 풀어볼 수도 있어요.
struct WrongNotesView: View {
    @EnvironmentObject var store: Store
    @FocusState private var focus: String?
    @State private var unitFilter: MathUnit?

    var body: some View {
        let all = store.wrongProblems
        let items = all.filter { unitFilter == nil || $0.problem.unit == unitFilter }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("단원", selection: $unitFilter) {
                    Text("전체 (\(all.count))").tag(MathUnit?.none)
                    ForEach(MathUnit.allCases) { u in
                        let n = all.filter { $0.problem.unit == u }.count
                        if n > 0 { Text("\(u.number). \(u.korean) (\(n))").tag(MathUnit?.some(u)) }
                    }
                }
                .pickerStyle(.menu)

                if items.isEmpty {
                    ContentUnavailableView("틀린 문제가 없어요 👏", systemImage: "checkmark.seal",
                                           description: Text("학습지를 채점하면 틀린 문제가 여기에 풀이와 함께 모여요."))
                }
                ForEach(items, id: \.problem.id) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.sheet.title)
                            .font(.caption).foregroundStyle(.secondary)
                        ProblemCard(problem: item.problem, index: (item.sheet.problems.firstIndex { $0.id == item.problem.id } ?? 0) + 1,
                                    sheetID: item.sheet.id, done: true, focus: $focus)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("오답노트")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { focus = nil }
            }
        }
    }
}
