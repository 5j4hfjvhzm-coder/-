import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("학습 방식", selection: $store.settings.studyMode) {
                        Text("한 단원씩 반복").tag(StudyMode.chapter)
                        Text("여러 단원 섞기").tag(StudyMode.mixed)
                    }
                    if store.settings.studyMode == .chapter {
                        Picker("지금 공부할 단원", selection: currentUnit) {
                            ForEach(store.settings.units) { u in
                                Text("\(u.number). \(u.korean)").tag(u)
                            }
                        }
                        Stepper("한 단원 기간: \(store.settings.chapterDays)일",
                                value: $store.settings.chapterDays, in: 7...60)
                        let p = store.settings.period(on: Day.today)
                        Text("\(Day.short(p.start)) ~ \(Day.short(p.end))까지 \(store.settings.unit(on: Day.today).korean)")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Stepper("하루 학습지: \(store.settings.sheetsPerDay)장",
                            value: $store.settings.sheetsPerDay, in: 1...10)
                    Stepper("학습지 1장 문제 수: \(store.settings.problemsPerDay)문제",
                            value: $store.settings.problemsPerDay, in: 5...20)
                    Picker("심화 문제", selection: $store.settings.challengePercent) {
                        Text("없음").tag(0)
                        Text("조금 (20%)").tag(20)
                        Text("많이 (40%)").tag(40)
                        Text("아주 많이 (60%)").tag(60)
                        Text("심화만 (100%)").tag(100)
                    }
                } header: {
                    Text("학습 계획")
                } footer: {
                    Text("한 단원씩 반복: 고른 단원만 정한 기간(기본 30일) 동안 매일 나와요. 기간이 끝나면 다음 단원으로 넘어가고, 마지막 단원 다음엔 처음 단원으로 돌아가 복습해요. 아래 단원 목록에서 끈 단원은 건너뛰어요.")
                }

                Section {
                    Toggle("주말은 쉬기 (토·일 학습지 없음)", isOn: $store.settings.skipWeekends)
                    Toggle("문제의 한국어 뜻 처음부터 펼쳐 보기", isOn: $store.settings.showKorean)
                    Toggle("연습장에 손가락으로도 쓰기", isOn: $store.settings.fingerDrawing)
                } header: {
                    Text("학습지")
                } footer: {
                    Text("설정을 바꾸면 아직 한 문제도 안 푼 학습지에도 바로 적용돼요. 손가락 쓰기를 끄면 연습장에는 Apple Pencil로만 쓰고, 손가락으로는 화면을 넘길 수 있어요.")
                }

                Section("단원 (5학년 2학기)") {
                    ForEach(MathUnit.allCases) { u in
                        Toggle(isOn: unitBinding(u)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(u.number). \(u.korean)")
                                Text(u.english).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tint(u.color)
                    }
                }

                Section {
                    Toggle("매일 알림", isOn: $store.settings.reminderOn)
                    if store.settings.reminderOn {
                        DatePicker("알림 시각", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("알림")
                } footer: {
                    Text("알림을 허용하면 앱 아이콘에 남은 학습지 수가 표시돼요.")
                }

                Section {
                    Button("기록 모두 지우기", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("푼 학습지와 밀린 학습지를 모두 지우고 오늘부터 다시 시작해요.")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
            .confirmationDialog("모든 기록을 지울까요? 되돌릴 수 없어요.", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("모두 지우기", role: .destructive) { store.resetAll() }
            }
        }
    }

    /// 단원을 고르면 오늘부터 그 단원 기간이 새로 시작돼요.
    private var currentUnit: Binding<MathUnit> {
        Binding(
            get: { store.settings.unit(on: Day.today) },
            set: { store.startChapter($0) }
        )
    }

    private func unitBinding(_ u: MathUnit) -> Binding<Bool> {
        Binding(
            get: { store.settings.units.contains(u) },
            set: { on in
                var us = store.settings.units
                if on { us.append(u) } else { us.removeAll { $0 == u } }
                let ordered = MathUnit.allCases.filter { us.contains($0) }
                // 단원은 하나 이상 남겨요
                if !ordered.isEmpty { store.settings.units = ordered }
            }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                let m = store.settings.reminderMinutes
                return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
            },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                store.settings.reminderMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}
