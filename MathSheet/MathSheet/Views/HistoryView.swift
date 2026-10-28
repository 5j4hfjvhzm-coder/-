import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        List {
            let stats = store.unitStats
            if !stats.isEmpty {
                Section("단원별 정답률") {
                    ForEach(stats) { st in
                        let u = st.unit
                        let right = st.right
                        let total = st.total
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(u.number). \(u.korean)")
                                Spacer()
                                Text("\(right)/\(total) · \(right * 100 / total)%")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(right), total: Double(total))
                                .tint(u.color)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("다 푼 학습지") {
                if store.done.isEmpty {
                    Text("아직 다 푼 학습지가 없어요.").foregroundStyle(.secondary)
                }
                ForEach(store.done) { sheet in
                    NavigationLink(value: Route.sheet(sheet.id)) {
                        SheetRow(sheet: sheet, highlight: false)
                    }
                }
            }
        }
        .navigationTitle("기록")
    }
}
