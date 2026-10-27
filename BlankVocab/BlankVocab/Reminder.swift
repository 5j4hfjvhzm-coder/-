import Foundation
import UserNotifications

/// 매일 정해진 시간에 학습 알림을 보내요.
enum Reminder {
    private static let id = "daily-study-reminder"

    /// 알림을 켜요. 권한이 없으면 false.
    static func enable(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "빈칸 단어장"
        content.body = "오늘의 학습을 할 시간이에요! 🔥 불꽃을 지켜 주세요."
        content.sound = .default
        var when = DateComponents()
        when.hour = hour
        when.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            return true
        } catch {
            return false
        }
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
