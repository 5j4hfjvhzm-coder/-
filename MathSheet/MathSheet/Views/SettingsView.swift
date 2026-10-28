import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("하루 문제 수: \(store.settings.problemsPerDay)문제",
                            value: $store.settings.problemsPerDay, in: 5...20)
                    Toggle("주말은 쉬기 (토·일 학습지 없음)", isOn: $store.settings.skipWeekends)
                } header: {
                    Text("학습지")
                } footer: {
                    Text("설정을 바꾸면 아직 한 문제도 안 푼 학습지에도 바로 적용돼요.")
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
