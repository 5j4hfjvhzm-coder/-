import UserNotifications

/// 매일 학습지 알림, 앱 아이콘 숫자(밀린 학습지 수)
enum Reminder {
    static func schedule(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let ok = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard ok else { return false }
        center.removePendingNotificationRequests(withIdentifiers: ["daily"])
        let content = UNMutableNotificationContent()
        content.title = "오늘의 수학 학습지 ✏️"
        content.body = "새 학습지가 도착했어요. 밀리기 전에 풀어 볼까요?"
        content.sound = .default
        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute
        let req = UNNotificationRequest(identifier: "daily", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
        try? await center.add(req)
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily"])
    }

    /// 알림을 허용했을 때만 아이콘에 숫자가 떠요.
    static func setBadge(_ n: Int) {
        UNUserNotificationCenter.current().setBadgeCount(n) { _ in }
    }
}
