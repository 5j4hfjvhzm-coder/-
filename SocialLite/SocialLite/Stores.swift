import Foundation
import Observation

// MARK: - 사용 시간

/// 플랫폼별 하루 사용 시간(초). 최근 30일만 보관해요.
@MainActor @Observable
final class UsageTracker {
    private(set) var days: [String: [String: Double]]
    /// "5분만 더" 로 늘린 시간. 날짜|플랫폼 → 초
    private var extra: [String: Double] = [:]
    @ObservationIgnored private var unsaved = 0

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        days = UserDefaults.standard.dictionary(forKey: "usage") as? [String: [String: Double]] ?? [:]
    }

    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }

    func seconds(_ p: Platform, on date: Date = .now) -> Double {
        days[Self.key(date)]?[p.rawValue] ?? 0
    }

    func total(on date: Date) -> Double {
        days[Self.key(date)]?.values.reduce(0, +) ?? 0
    }

    func add(_ s: Double, to p: Platform) {
        days[Self.key(.now), default: [:]][p.rawValue, default: 0] += s
        unsaved += 1
        if unsaved >= 15 { save() }
    }

    func extraSeconds(_ p: Platform) -> Double {
        extra["\(Self.key(.now))|\(p.rawValue)"] ?? 0
    }

    func grantExtra(_ s: Double, to p: Platform) {
        extra["\(Self.key(.now))|\(p.rawValue)", default: 0] += s
    }

    func save() {
        unsaved = 0
        if let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) {
            let oldest = Self.key(cutoff)
            days = days.filter { $0.key >= oldest }
        }
        UserDefaults.standard.set(days, forKey: "usage")
    }
}

// MARK: - 저장한 링크

struct Bookmark: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var url: URL
    var platform: Platform?
    var added = Date()
}

@MainActor @Observable
final class BookmarkStore {
    private(set) var items: [Bookmark]

    init() {
        if let data = UserDefaults.standard.data(forKey: "bookmarks"),
           let list = try? JSONDecoder().decode([Bookmark].self, from: data) {
            items = list
        } else {
            items = []
        }
    }

    func contains(_ url: URL) -> Bool {
        let clean = Platform.cleanShareURL(url)
        return items.contains { $0.url == clean }
    }

    /// 저장되어 있으면 지우고, 없으면 저장. 저장했으면 true.
    @discardableResult
    func toggle(title: String, url: URL) -> Bool {
        let clean = Platform.cleanShareURL(url)
        if let i = items.firstIndex(where: { $0.url == clean }) {
            items.remove(at: i)
            save()
            return false
        }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        items.insert(Bookmark(title: name.isEmpty ? clean.absoluteString : name,
                              url: clean, platform: Platform.matching(clean)), at: 0)
        save()
        return true
    }

    func remove(_ ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "bookmarks")
        }
    }
}
