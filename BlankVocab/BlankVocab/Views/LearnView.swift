import SwiftUI

/// 4지선다 종류
enum ChoiceKind: String, Hashable {
    /// 영어 단어를 보고 뜻 고르기
    case meaning
    /// 뜻을 보고 영어 단어 고르기
    case word
    /// 실력 진단 (20문제, 섞어서)
    case levelTest
}

/// 학습 홈: 오늘의 학습, 연속 학습, 하루 목표, 여러 학습 모드
struct LearnView: View {
    let bookIDs: [Int]
    @Environment(Store.self) private var store

    var body: some View {
        let due = store.dueWords(bookIDs).count
        let new = store.newWords(bookIDs).count
        let goal = store.data.goal
        let today = store.todayCount

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 연속 학습 · 오늘 진행
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🔥 \(store.streak)일 연속")
                            .font(.system(size: 24, weight: .heavy))
                        Text(today >= Store.streakMin ? "오늘 불꽃을 지켰어요!" : "오늘 \(Store.streakMin - today)문제 더 풀면 불꽃이 이어져요")
                            .font(.footnote).foregroundStyle(Theme.sub)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(Theme.soft, lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: min(Double(today) / Double(max(goal, 1)), 1))
                            .stroke(Theme.pri, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(today)").font(.headline.weight(.heavy))
                            Text("/\(goal)").font(.caption2).foregroundStyle(Theme.sub)
                        }
                    }
                    .frame(width: 64, height: 64)
                }
                .card()

                // 오늘의 학습
                VStack(alignment: .leading, spacing: 10) {
                    Text("오늘의 학습").font(.title3.weight(.heavy))
                    Text("복습할 단어 \(due)개 · 새 단어 \(min(new, goal))개 (하루 목표 \(goal)개)")
                        .font(.subheadline).foregroundStyle(Theme.sub)
                    Text("빈칸 문제로 풀고, 맞힌 단어는 1일 → 3일 → 7일 → 21일 → 30일 뒤에 다시 복습해요. 틀린 단어는 금방 다시 나와요.")
                        .font(.footnote).foregroundStyle(Theme.sub)
                    HStack {
                        Button("학습 시작") { store.startToday(bookIDs) }
                            .buttonStyle(.pillPrimary)
                            .disabled(due == 0 && new == 0)
                        Spacer()
                        Menu {
                            ForEach([5, 10, 20, 50], id: \.self) { n in
                                Button { store.setGoal(n) } label: {
                                    Text(goalName(n)) + Text(n == goal ? " ✓" : "")
                                }
                            }
                        } label: {
                            Label("하루 목표 \(goal)개", systemImage: "target").font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .card()

                SectionTitle("학습 모드")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile("🔤", "뜻 고르기", "단어 보고 4지선다", .choice(bookIDs, .meaning))
                    tile("🇰🇷", "단어 고르기", "뜻 보고 4지선다", .choice(bookIDs, .word))
                    Button {
                        store.start(.listen, ids: bookIDs, multi: true)
                    } label: {
                        tileLabel("🎧", "리스닝", "듣고 빈칸 채우기")
                    }
                    .buttonStyle(.plain)
                    tile("🧩", "문장 배열", "카드로 문장 완성", .arrange(bookIDs))
                    tile("🗣️", "스피킹", "따라 말하고 점수 받기", .speak(bookIDs))
                    tile("🧠", "기억력 부스터", "최근 7일 문장 듣기", .booster(bookIDs))
                    tile("🃏", "플래시카드", "뒤집으며 외우기", .flash(bookIDs))
                    tile("📝", "오답노트", "자주 틀린 단어", .wrongNote(bookIDs))
                    tile("📊", "실력 진단", "20문제로 확인", .choice(bookIDs, .levelTest))
                    tile("📈", "학습 통계", "기록 한눈에 보기", .stats(bookIDs))
                    tile("🤖", "AI 프리토킹", "영어로 대화하기", .chat(bookIDs))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .navigationTitle("학습")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func goalName(_ n: Int) -> String {
        switch n {
        case 5: return "여유롭게 5개"
        case 10: return "적당하게 10개"
        case 20: return "열심히 20개"
        default: return "열정적으로 \(n)개"
        }
    }

    private func tile(_ icon: String, _ title: String, _ sub: String, _ route: Route) -> some View {
        NavigationLink(value: route) { tileLabel(icon, title, sub) }
            .buttonStyle(.plain)
    }

    private func tileLabel(_ icon: String, _ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(icon).font(.title2)
            Text(title).font(.headline)
            Text(sub).font(.caption).foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
    }
}
