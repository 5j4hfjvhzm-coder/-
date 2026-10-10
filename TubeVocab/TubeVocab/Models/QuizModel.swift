import Foundation
import Observation

/// 빈칸 시험. 예전 "빈칸 단어장" 앱과 같은 방식:
/// 전체 퀴즈 / 전체 테스트(힌트·읽기 없음) / ★ 헷갈리는 단어만, 섞어서 한 바퀴,
/// 틀린 문제 다시 풀기, 저장하고 나가기 → 이어서 하기.
enum QuizMode: String, Codable, CaseIterable {
    case all, test, star

    var label: String {
        switch self {
        case .all: return "전체 퀴즈"
        case .test: return "전체 테스트"
        case .star: return "★ 헷갈리는 단어"
        }
    }
}

/// 진행 중인 시험
struct QuizRun {
    struct Done {
        var ok: Bool
        var val: String
    }

    var list: [UUID]
    var i = 0
    var ok = 0
    var done: Done?
    var hint = false
    var wrong: [UUID] = []
    var mode: QuizMode
    var label: String
    var sid: Int

    var n: Int { list.count }
    var isTest: Bool { mode == .test }
    var finished: Bool { i >= list.count }
    var currentID: UUID? { i < list.count ? list[i] : nil }
    var uniqueWrong: [UUID] { uniqued(wrong) }
}

/// "저장하고 나가기"로 저장된 풀이
struct SavedQuiz: Codable, Identifiable, Hashable {
    var sid: Int
    var label: String
    var mode: QuizMode
    var list: [UUID]
    var i: Int
    var ok: Int
    var wrong: [UUID]
    var t: Date

    var id: Int { sid }
}

struct QuizData: Codable {
    var sess: [SavedQuiz] = []
    /// ★ 헷갈리는 단어는 빼고 풀기
    var skip = false
    /// 정답 확인 후 문장 자동으로 읽기
    var auto = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sess = (try? c.decodeIfPresent([SavedQuiz].self, forKey: .sess)) ?? []
        skip = (try? c.decodeIfPresent(Bool.self, forKey: .skip)) ?? false
        auto = (try? c.decodeIfPresent(Bool.self, forKey: .auto)) ?? false
    }
}

@MainActor
@Observable
final class QuizModel {
    private(set) var data = QuizData()
    var run: QuizRun?
    var toast: String?

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(fileURL: URL = URL.documentsDirectory.appending(path: "quiz.json")) {
        self.fileURL = fileURL
        if let d = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(QuizData.self, from: d) {
            data = decoded
        }
    }

    private func save() {
        try? JSONEncoder().encode(data).write(to: fileURL, options: .atomic)
    }

    func show(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func setSkip(_ v: Bool) { data.skip = v; save() }
    func setAuto(_ v: Bool) { data.auto = v; save() }

    /// 시험에 나올 단어 수 (★ 빼기 반영)
    func count(_ words: [SavedWord]) -> Int {
        words.filter { !data.skip || !$0.star }.count
    }

    // MARK: 진행

    func start(_ mode: QuizMode, words: [SavedWord]) {
        var l = words
        if mode == .star {
            l = l.filter(\.star)
        } else if data.skip {
            l = l.filter { !$0.star }
        }
        guard !l.isEmpty else { return }
        let label = mode.label + (data.skip && mode != .star ? " (★ 제외)" : "")
        run = QuizRun(list: l.map(\.id).shuffled(), mode: mode, label: label, sid: Self.newSID())
    }

    /// 확인. 활용형·기본형 모두 정답. 맞았는지 돌려준다 (이미 확인했거나 빈 답이면 nil).
    @discardableResult
    func check(_ answer: String, word: SavedWord, blankAnswer: String) -> Bool? {
        guard var q = run, q.done == nil else { return nil }
        let v = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return nil }
        let ok = isCorrect(v, word.target, blankAnswer: blankAnswer)
        if ok { q.ok += 1 } else { q.wrong.append(word.id) }
        q.done = QuizRun.Done(ok: ok, val: v)
        run = q
        if data.auto { Speech.shared.say(word.sentenceEn) }
        return ok
    }

    func next() {
        guard var q = run else { return }
        q.i += 1
        q.done = nil
        q.hint = false
        run = q
        if q.finished, data.sess.contains(where: { $0.sid == q.sid }) {
            data.sess.removeAll { $0.sid == q.sid }
            save()
        }
    }

    func showHint() { run?.hint = true }

    func saveSession() {
        guard let q = run else { return }
        let i = q.i + (q.done != nil ? 1 : 0)
        data.sess.removeAll { $0.sid == q.sid }
        if i < q.list.count {
            data.sess.insert(SavedQuiz(sid: q.sid, label: q.label, mode: q.mode, list: q.list, i: i,
                                       ok: q.ok, wrong: q.wrong, t: Date()), at: 0)
            show("저장했어요. \"이어서 하기\"에서 계속할 수 있어요.")
        } else {
            show("이미 끝났어요.")
        }
        save()
        run = nil
    }

    /// 저장한 풀이 이어서 하기 (그 사이 지운 단어는 빼고)
    func resume(_ sid: Int, words: [SavedWord]) {
        guard let o = data.sess.first(where: { $0.sid == sid }) else { return }
        let alive = Set(words.map(\.id))
        let list = o.list.filter { alive.contains($0) }
        let i = o.list.prefix(o.i).filter { alive.contains($0) }.count
        guard i < list.count else { deleteSession(sid); return }
        run = QuizRun(list: list, i: i, ok: o.ok, wrong: o.wrong.filter { alive.contains($0) },
                      mode: o.mode, label: o.label, sid: o.sid)
    }

    func deleteSession(_ sid: Int) {
        data.sess.removeAll { $0.sid == sid }
        save()
    }

    func retryWrong() {
        guard var q = run else { return }
        let l = q.uniqueWrong.shuffled()
        guard !l.isEmpty else { return }
        q.list = l
        q.i = 0
        q.ok = 0
        q.done = nil
        q.hint = false
        q.wrong = []
        q.label = "틀린 문제 다시 · " + q.label
        q.sid = Self.newSID()
        run = q
    }

    func restart(words: [SavedWord]) {
        guard let q = run else { return }
        start(q.mode, words: words)
    }

    private static func newSID() -> Int {
        Int(Date().timeIntervalSince1970 * 1000) + Int.random(in: 0..<1000)
    }
}
