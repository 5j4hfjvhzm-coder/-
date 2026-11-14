import SwiftUI
import Charts

struct UsageView: View {
    @Environment(AppModel.self) private var model

    private struct Entry: Identifiable {
        let day: Date
        let platform: Platform
        let minutes: Double
        var id: String { "\(Int(day.timeIntervalSince1970))-\(platform.rawValue)" }
    }

    private var lastWeek: [Date] {
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
    }

    private var entries: [Entry] {
        lastWeek.flatMap { day in
            Platform.allCases.map { Entry(day: day, platform: $0, minutes: model.usage.seconds($0, on: day) / 60) }
        }
    }

    var body: some View {
        List {
            Section {
                Chart(entries) { e in
                    BarMark(
                        x: .value("날짜", e.day, unit: .day),
                        y: .value("분", e.minutes)
                    )
                    .foregroundStyle(by: .value("앱", e.platform.name))
                }
                .chartForegroundStyleScale(
                    domain: Platform.allCases.map(\.name),
                    range: Platform.allCases.map(\.tint)
                )
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxisLabel("분")
                .frame(height: 220)
                .padding(.vertical, 8)
            }

            Section("하루 합계") {
                ForEach(lastWeek.reversed(), id: \.self) { day in
                    HStack {
                        Text(day, format: .dateTime.month().day().weekday(.abbreviated))
                        Spacer()
                        Text(formatDuration(model.usage.total(on: day)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("사용 시간")
        .navigationBarTitleDisplayMode(.inline)
    }
}
