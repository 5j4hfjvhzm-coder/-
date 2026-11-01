import SwiftUI

/// 단원별 연습: 매일 학습지와 상관없이, 원하는 단원을 골라 언제든 풀어요.
struct PracticeView: View {
    @EnvironmentObject var store: Store
    @Binding var selection: Route?

    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("원하는 단원을 골라 연습 학습지를 풀어요. 매일 학습지와 따로라서 밀린 학습지에 쌓이지 않아요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(MathUnit.allCases) { unit in
                        card(unit)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("단원별 연습")
    }

    private func card(_ unit: MathUnit) -> some View {
        let sheets = store.practiceSheets(unit)
        let unfinished = sheets.first { !$0.isDone }
        let doneSheets = sheets.filter(\.isDone)
        let solved = doneSheets.reduce(0) { $0 + $1.problems.count }
        let right = doneSheets.reduce(0) { $0 + $1.score }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("\(unit.number)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(unit.color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(unit.korean).font(.headline)
                    Text(unit.english).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text(solved == 0 ? "아직 연습하지 않았어요" : "연습 \(doneSheets.count)장 · 정답률 \(right * 100 / solved)%")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                if let s = unfinished {
                    Button {
                        selection = .sheet(s.id)
                    } label: {
                        Label("이어 풀기 (\(s.seq)회)", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    selection = .sheet(store.newPractice(unit))
                } label: {
                    Label("새 학습지", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(unit.color)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}
