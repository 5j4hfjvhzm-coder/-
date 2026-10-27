import SwiftUI

/// 학습 통계: 연속 학습, 최근 14일 기록, 단어 진행 상황
struct StatsView: View {
    let bookIDs: [Int]
    @Environment(Store.self) private var store

    var body: some View {
        let words = store.words(in: bookIDs)
        let new = words.filter(\.isNew).count
        let mastered = words.filter(\.isMastered).count
        let learning = words.count - new - mastered
        let days = last14
        let maxCount = max(days.map(\.count).max() ?? 0, 1)
        let total = store.data.history.values.reduce(0, +)

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    stat("🔥", "\(store.streak)일", "연속 학습")
                    stat("✏️", "\(store.todayCount)", "오늘 푼 문제")
                    stat("📚", "\(total)", "지금까지")
                }

                SectionTitle("최근 14일")
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(days, id: \.key) { d in
                            VStack(spacing: 4) {
                                Text(d.count > 0 ? "\(d.count)" : "")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.sub)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(d.count >= Store.streakMin ? Theme.pri : Theme.soft)
                                    .frame(height: max(4, 110 * CGFloat(d.count) / CGFloat(maxCount)))
                                Text(d.label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.sub)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 150, alignment: .bottom)
                    Text("보라색 막대는 \(Store.streakMin)문제 이상 풀어 불꽃을 지킨 날이에요.")
                        .font(.caption).foregroundStyle(Theme.sub)
                }
                .card()

                SectionTitle("단어 진행 상황")
                VStack(alignment: .leading, spacing: 10) {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Rectangle().fill(Theme.ok)
                                .frame(width: geo.size.width * share(mastered, words.count))
                            Rectangle().fill(Theme.pri)
                                .frame(width: geo.size.width * share(learning, words.count))
                            Rectangle().fill(Theme.soft)
                        }
                    }
                    .frame(height: 14)
                    .clipShape(Capsule())
                    legend(Theme.ok, "외운 단어", mastered)
                    legend(Theme.pri, "학습 중", learning)
                    legend(Theme.soft, "아직 안 배운 단어", new)
                    legend(Theme.bad, "지금 복습할 단어", store.dueWords(bookIDs).count)
                }
                .card()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .navigationTitle("학습 통계")
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct Day {
        let key: String
        let label: String
        let count: Int
    }

    private var last14: [Day] {
        let cal = Calendar.current
        return (0..<14).reversed().compactMap { offset -> Day? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let key = Store.dayKey(d)
            return Day(key: key, label: "\(cal.component(.day, from: d))", count: store.data.history[key] ?? 0)
        }
    }

    private func share(_ n: Int, _ total: Int) -> CGFloat {
        total == 0 ? 0 : CGFloat(n) / CGFloat(total)
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(icon).font(.title3)
            Text(value).font(.title3.weight(.heavy)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func legend(_ color: Color, _ label: String, _ n: Int) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(label).font(.subheadline)
            Spacer()
            Text("\(n)개").font(.subheadline.weight(.semibold)).monospacedDigit()
        }
    }
}
