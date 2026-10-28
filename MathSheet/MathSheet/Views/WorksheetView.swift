import SwiftUI

struct WorksheetView: View {
    @EnvironmentObject var store: Store
    let sheetID: String
    @Binding var path: [Route]

    @FocusState private var focus: String?
    @State private var confirmSubmit = false

    var body: some View {
        Group {
            if let sheet = store.sheet(sheetID) {
                content(sheet)
            } else {
                ContentUnavailableView("학습지가 없어요", systemImage: "doc.questionmark")
            }
        }
        .navigationTitle(Day.label(sheetID))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ sheet: Worksheet) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    header(sheet).id("top")

                    ForEach(Array(sheet.problems.enumerated()), id: \.element.id) { i, p in
                        ProblemCard(problem: p, index: i + 1, sheetID: sheet.id, done: sheet.isDone, focus: $focus)
                    }

                    footer(sheet, proxy: proxy)
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    if let next = nextInput(after: focus, in: sheet) {
                        Button("다음") { focus = next }
                    }
                    Button("완료") { focus = nil }
                }
            }
            .confirmationDialog("아직 \(sheet.problems.count - sheet.answeredCount)문제를 안 풀었어요. 그래도 채점할까요?",
                                isPresented: $confirmSubmit, titleVisibility: .visible) {
                Button("채점하기") { submit(sheet, proxy: proxy) }
                Button("더 풀래요", role: .cancel) {}
            }
        }
    }

    private func header(_ sheet: Worksheet) -> some View {
        VStack(spacing: 8) {
            if sheet.isDone {
                let s = sheet.score
                let n = sheet.problems.count
                Text(s == n ? "🏆" : s * 10 >= n * 8 ? "🎉" : s * 2 >= n ? "👍" : "💪").font(.system(size: 44))
                Text("\(s) / \(n)").font(.largeTitle.bold().monospacedDigit())
                Text(s == n ? "Perfect! 모두 맞았어요" : "틀린 문제는 풀이를 보고 다시 풀어 봐요")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("Daily Math Worksheet").font(.title3.bold())
                Text("Grade 5 · Semester 2  —  \(sheet.answeredCount) / \(sheet.problems.count) answered")
                    .font(.subheadline).foregroundStyle(.secondary)
                ProgressView(value: Double(sheet.answeredCount), total: Double(max(sheet.problems.count, 1)))
                    .tint(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    @ViewBuilder
    private func footer(_ sheet: Worksheet, proxy: ScrollViewProxy) -> some View {
        if !sheet.isDone {
            Button {
                focus = nil
                if sheet.answeredCount < sheet.problems.count { confirmSubmit = true } else { submit(sheet, proxy: proxy) }
            } label: {
                Label("채점하기", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 6)
        } else if let next = store.pending.first {
            Button {
                path = [.sheet(next.id)]
            } label: {
                Label("다음 학습지 풀기 (\(Day.label(next.id)))", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        } else {
            Text("밀린 학습지가 없어요. 내일 또 만나요! 👋")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    private func submit(_ sheet: Worksheet, proxy: ScrollViewProxy) {
        store.submit(sheet.id)
        withAnimation { proxy.scrollTo("top", anchor: .top) }
    }

    /// 키보드 "다음": 다음 입력 칸으로
    private func nextInput(after id: String?, in sheet: Worksheet) -> String? {
        guard !sheet.isDone, let id, let i = sheet.problems.firstIndex(where: { $0.id == id }) else { return nil }
        return sheet.problems[(i + 1)...].first(where: { $0.kind == .number })?.id
    }
}
