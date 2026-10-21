import Foundation

/// 단어 하나. 웹 버전 백업(.json)과 같은 키(w, m, e, p, star, id)를 사용해 서로 호환돼요.
/// CSV의 나머지 열(성별, 발음, 파생어, 유의어, 동의어, 반의어, 설명, 날짜, 이미지)도 함께 저장해요.
struct Word: Codable, Identifiable, Hashable {
    var id: String
    var w: String
    var m: String
    var e: String
    /// 품사(POS)
    var p: String
    var star: Bool
    /// 성별(G)
    var g: String = ""
    /// 발음(P)
    var pron: String = ""
    /// 파생어(DER)
    var der: String = ""
    /// 유의어(SIM)
    var sim: String = ""
    /// 동의어(S)
    var syn: String = ""
    /// 반의어(A)
    var ant: String = ""
    /// 설명(D)
    var d: String = ""
    /// 날짜(C)
    var c: String = ""
    /// 이미지(I) — 주소(URL)나 파일 이름
    var img: String = ""

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

    /// 정답을 확인한 뒤에 보여줄 추가 정보 (값이 있는 것만, CSV 열 순서대로)
    var details: [WordDetail] {
        [WordDetail(label: "품사", value: p), WordDetail(label: "발음", value: pron), WordDetail(label: "성별", value: g),
         WordDetail(label: "설명", value: d), WordDetail(label: "파생어", value: der), WordDetail(label: "유의어", value: sim),
         WordDetail(label: "동의어", value: syn), WordDetail(label: "반의어", value: ant)]
            .filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var imageURL: URL? {
        let s = img.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.lowercased().hasPrefix("http://") || s.lowercased().hasPrefix("https://") else { return nil }
        return URL(string: s)
    }

    enum CodingKeys: String, CodingKey { case id, w, m, e, p, star, g, pron, der, sim, syn, ant, d, c, img }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func str(_ k: CodingKeys) -> String { (try? c.decodeIfPresent(String.self, forKey: k)) ?? "" }
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? Word.newID()
        w = str(.w)
        m = str(.m)
        e = str(.e)
        p = str(.p)
        star = (try? c.decodeIfPresent(Bool.self, forKey: .star)) ?? false
        g = str(.g)
        pron = str(.pron)
        der = str(.der)
        sim = str(.sim)
        syn = str(.syn)
        ant = str(.ant)
        d = str(.d)
        self.c = str(.c)
        img = str(.img)
    }
}

struct WordDetail: Identifiable, Hashable {
    var label: String
    var value: String
    var id: String { label }
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
        /// "정답 보기"로 답을 먼저 본 경우
        var revealed = false
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
