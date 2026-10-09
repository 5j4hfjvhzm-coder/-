import Foundation

/// 단어 하나. 웹 버전 백업(.json)과 같은 키(w, m, e, p, star, id)를 사용해 서로 호환돼요.
struct Word: Codable, Identifiable, Hashable {
    var id: String
    var w: String
    var m: String
    var e: String
    var p: String
    var star: Bool

    init(w: String, m: String, e: String = "", p: String = "", star: Bool = false, id: String = Word.newID()) {
        self.id = id
        self.w = w
        self.m = m
        self.e = e
        self.p = p
        self.star = star
    }

    static func newID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)).lowercased()
    }

    enum CodingKeys: String, CodingKey { case id, w, m, e, p, star }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? Word.newID()
        w = (try? c.decodeIfPresent(String.self, forKey: .w)) ?? ""
        m = (try? c.decodeIfPresent(String.self, forKey: .m)) ?? ""
        e = (try? c.decodeIfPresent(String.self, forKey: .e)) ?? ""
        p = (try? c.decodeIfPresent(String.self, forKey: .p)) ?? ""
        star = (try? c.decodeIfPresent(Bool.self, forKey: .star)) ?? false
    }
}

struct Book: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var words: [Word]

    enum CodingKeys: String, CodingKey { case id, name, words }

    init(id: Int, name: String, words: [Word]) {
        self.id = id
        self.name = name
        self.words = words
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decodeIfPresent(Int.self, forKey: .id) {
            id = i
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .id) {
            id = Int(d)
        } else {
            id = Book.newID()
        }
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "단어장"
        words = (try? c.decodeIfPresent([Word].self, forKey: .words)) ?? []
    }

    static func newID() -> Int { Int(Date().timeIntervalSince1970 * 1000) + Int.random(in: 0..<1000) }
}

enum QuizMode: String, Codable {
    case all, test, star

    var label: String {
        switch self {
        case .all: return "전체 퀴즈"
        case .test: return "전체 테스트"
        case .star: return "★ 헷갈리는 단어"
        }
    }
}

/// "저장하고 나가기"로 저장된 풀이 기록
struct SavedSession: Codable, Identifiable, Hashable {
    var sid: Int
    var label: String
    var mode: QuizMode
    var sc: [Int]
    var multi: Bool
    var list: [String]
    var i: Int
    var ok: Int
    var wrong: [String]
    var t: Date

    var id: Int { sid }
}

struct AppData: Codable {
    var books: [Book] = []
    var sess: [SavedSession] = []
    var skip: Bool = false
    var auto: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        books = (try? c.decodeIfPresent([Book].self, forKey: .books)) ?? []
        sess = (try? c.decodeIfPresent([SavedSession].self, forKey: .sess)) ?? []
        skip = (try? c.decodeIfPresent(Bool.self, forKey: .skip)) ?? false
        auto = (try? c.decodeIfPresent(Bool.self, forKey: .auto)) ?? false
    }
}

/// 백업 파일 형식 (웹 버전과 동일: {"books": [...]})
struct Backup: Codable {
    var books: [Book]
}

/// 진행 중인 퀴즈
struct Quiz {
    struct Done {
        var ok: Bool
        var val: String
    }

    var list: [Word]
    var i = 0
    var ok = 0
    var done: Done?
    var hint = false
    var wrong: [Word] = []
    var mode: QuizMode
    /// 여러 단어장에서 시작했으면 그 단어장 id 목록 (끝나면 홈으로 돌아가요)
    var ids: [Int]?
    var sc: [Int]
    var label: String
    var sid: Int
    var explanation = ""
    var explaining = false

    var n: Int { list.count }
    var isTest: Bool { mode == .test }
    var finished: Bool { i >= list.count }
    var current: Word? { i < list.count ? list[i] : nil }
    var uniqueWrong: [Word] {
        var seen = Set<String>()
        return wrong.filter { seen.insert($0.id).inserted }
    }
}

struct ChatMessage: Identifiable, Hashable {
    enum Role: String { case user, assistant }
    let id = UUID()
    var role: Role
    var text: String

    /// AI 답변은 "---" 줄을 기준으로 [영어 답변, 한국어 피드백]으로 나눠요.
    var parts: (reply: String, feedback: String?) {
        guard role == .assistant else { return (text, nil) }
        if let r = text.range(of: #"\n-{3,}[ \t]*\n?"#, options: .regularExpression) {
            let a = String(text[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let f = String(text[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (a, f.isEmpty ? nil : f)
        }
        return (text, nil)
    }
}
