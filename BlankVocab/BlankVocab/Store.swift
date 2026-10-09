import Foundation
import Observation

@MainActor
@Observable
final class Store {
    var data = AppData()
    var quiz: Quiz?
    var toast: String?

    @ObservationIgnored private var toastTask: Task<Void, Never>?
    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("blankvocab.json")
    }()

    init() {
        load()
    }

    // MARK: - 저장

    private func load() {
        guard let d = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.app.decode(AppData.self, from: d) else { return }
        data = decoded
    }

    func save() {
        do {
            let d = try JSONEncoder.app.encode(data)
            try d.write(to: fileURL, options: .atomic)
        } catch {
            show("저장하지 못했어요.")
        }
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

    // MARK: - 단어장

    func book(_ id: Int) -> Book? { data.books.first { $0.id == id } }

    private func bookIndex(_ id: Int) -> Int? { data.books.firstIndex { $0.id == id } }

    @discardableResult
    func addBook(name: String, words: [Word] = []) -> Int {
        var id = Book.newID()
        while data.books.contains(where: { $0.id == id }) { id += 1 }
        data.books.append(Book(id: id, name: name, words: words))
        save()
        return id
    }

    func deleteBook(_ id: Int) {
        data.books.removeAll { $0.id == id }
        save()
    }

    func addWord(to bookID: Int, _ word: Word) {
        guard let b = bookIndex(bookID) else { return }
        data.books[b].words.append(word)
        save()
    }

    func addWords(to bookID: Int, _ words: [Word]) {
        guard let b = bookIndex(bookID) else { return }
        data.books[b].words.append(contentsOf: words)
        save()
    }

    func deleteWord(bookID: Int, wordID: String) {
        guard let b = bookIndex(bookID) else { return }
        data.books[b].words.removeAll { $0.id == wordID }
        save()
    }

    /// 헷갈리는 단어(★) 표시 토글. 진행 중인 퀴즈의 단어에도 반영해요.
    func toggleStar(wordID: String) {
        for b in data.books.indices {
            for w in data.books[b].words.indices where data.books[b].words[w].id == wordID {
                data.books[b].words[w].star.toggle()
            }
        }
        if var q = quiz {
            for i in q.list.indices where q.list[i].id == wordID { q.list[i].star.toggle() }
            quiz = q
        }
        save()
    }

    func addSample() {
        let csv = """
        단어(W),의미(M),예문(E)
        responsible,책임감 있는,She is responsible for the project.
        resource,자원,Water is an important resource.
        respect,존중하다,Students should respect their teachers.
        solve,해결하다,Can you solve this problem?
        suggest,제안하다,I suggest taking a break.
        """
        addBook(name: "샘플 단어장", words: CSV.words(from: CSV.parse(csv)))
    }

    func setSkip(_ v: Bool) { data.skip = v; save() }
    func setAuto(_ v: Bool) { data.auto = v; save() }

    func words(in ids: [Int]) -> [Word] {
        data.books.filter { ids.contains($0.id) }.flatMap(\.words)
    }

    /// 퀴즈에 나올 단어 수 (★ 제외 옵션 반영)
    func count(_ ids: [Int]) -> Int {
        words(in: ids).filter { !data.skip || !$0.star }.count
    }

    func starCount(_ ids: [Int]) -> Int {
        words(in: ids).filter(\.star).count
    }

    // MARK: - 파일 가져오기

    /// CSV / 백업(.json) 파일 가져오기. intoBook 이 있으면 그 단어장에 단어를 추가해요.
    func importFiles(_ urls: [URL], intoBook: Int? = nil) {
        var added = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let d = try? Data(contentsOf: url) else {
                show("\(url.lastPathComponent): 파일을 읽지 못했어요.")
                continue
            }
            if url.pathExtension.lowercased() == "json" {
                guard let backup = try? JSONDecoder.app.decode(Backup.self, from: d) else {
                    show("백업 파일을 읽지 못했어요.")
                    continue
                }
                for b in backup.books { addBook(name: b.name, words: b.words) }
                added += 1
                continue
            }
            let ws = CSV.decode(d).map { CSV.words(from: CSV.parse($0)) } ?? []
            if ws.isEmpty {
                show("\(url.lastPathComponent): 단어를 찾지 못했어요. 첫 줄에 단어, 의미, 예문 열이 있어야 해요.")
                continue
            }
            if let bid = intoBook {
                addWords(to: bid, ws)
            } else {
                var name = url.deletingPathExtension().lastPathComponent
                if name.hasSuffix("_UTF8") { name.removeLast(5) }
                addBook(name: name, words: ws)
            }
            added += 1
        }
        if added > 0 { show("가져왔어요.") }
    }

    func backupData() -> Data {
        (try? JSONEncoder.app.encode(Backup(books: data.books))) ?? Data()
    }

    // MARK: - 퀴즈

    func start(_ mode: QuizMode, ids: [Int], multi: Bool) {
        let books = data.books.filter { ids.contains($0.id) }
        var l = books.flatMap(\.words)
        if mode == .star {
            l = l.filter(\.star)
        } else if data.skip {
            l = l.filter { !$0.star }
        }
        l.shuffle()
        guard !l.isEmpty else { return }
        let label = mode.label + (data.skip && mode != .star ? " (★ 제외)" : "") + " · " + books.map(\.name).joined(separator: ", ")
        quiz = Quiz(list: l, mode: mode, ids: multi ? ids : nil, sc: ids, label: label, sid: Book.newID())
    }

    func check(_ answer: String) {
        guard var q = quiz, q.done == nil, let x = q.current else { return }
        let v = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !v.isEmpty else { return }
        let ok = v == Blank(x).ans.lowercased()
        if ok { q.ok += 1 } else { q.wrong.append(x) }
        q.done = Quiz.Done(ok: ok, val: v)
        q.explanation = ""
        quiz = q
        if data.auto { Speech.shared.say(Blank(x).fullSentence) }
    }

    func next() {
        guard var q = quiz else { return }
        q.explanation = ""
        q.i += 1
        q.done = nil
        q.hint = false
        quiz = q
        if q.finished, data.sess.contains(where: { $0.sid == q.sid }) {
            data.sess.removeAll { $0.sid == q.sid }
            save()
        }
    }

    func showHint() { quiz?.hint = true }

    func saveSession() {
        guard let q = quiz else { return }
        let i = q.i + (q.done != nil ? 1 : 0)
        data.sess.removeAll { $0.sid == q.sid }
        if i < q.list.count {
            data.sess.insert(SavedSession(sid: q.sid, label: q.label, mode: q.mode, sc: q.sc, multi: q.ids != nil,
                                          list: q.list.map(\.id), i: i, ok: q.ok, wrong: q.wrong.map(\.id), t: Date()), at: 0)
            show("저장했어요. 첫 화면의 \"이어서 하기\"에서 계속할 수 있어요.")
        } else {
            show("이미 끝났어요.")
        }
        save()
        quiz = nil
    }

    func resume(_ sid: Int) {
        guard let o = data.sess.first(where: { $0.sid == sid }) else { return }
        let all = Dictionary(data.books.flatMap(\.words).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let list = o.list.compactMap { all[$0] }
        let i = o.list.prefix(o.i).filter { all[$0] != nil }.count
        guard i < list.count else { deleteSession(sid); return }
        quiz = Quiz(list: list, i: i, ok: o.ok, wrong: o.wrong.compactMap { all[$0] }, mode: o.mode,
                    ids: o.multi ? o.sc : nil, sc: o.sc, label: o.label, sid: o.sid)
    }

    func deleteSession(_ sid: Int) {
        data.sess.removeAll { $0.sid == sid }
        save()
    }

    func retryWrong() {
        guard var q = quiz else { return }
        let l = q.uniqueWrong.shuffled()
        guard !l.isEmpty else { return }
        q.list = l
        q.i = 0
        q.ok = 0
        q.done = nil
        q.hint = false
        q.wrong = []
        q.explanation = ""
        q.label = "틀린 문제 다시 · " + q.label
        q.sid = Book.newID()
        quiz = q
    }

    func restart() {
        guard let q = quiz else { return }
        start(q.mode, ids: q.sc, multi: q.ids != nil)
    }

    // MARK: - AI 설명

    func explainWrong() async {
        guard var q = quiz, let x = q.current, let done = q.done else { return }
        guard let client = ClaudeClient.fromSettings() else {
            quiz?.explanation = "AI 기능을 쓰려면 첫 화면 오른쪽 위 ⚙︎ 설정에서 Claude API 키를 입력하세요."
            return
        }
        let b = Blank(x)
        q.explanation = "AI가 설명 중…"
        q.explaining = true
        quiz = q
        let sid = q.sid, idx = q.i
        let prompt = """
        영어를 배우는 한국 학생이 빈칸 문제를 틀렸어요. 한국어로 6줄 이내로 답하세요.
        문장: \(b.pre)____\(b.post)
        뜻: \(x.m)
        정답: \(b.ans)
        학생의 답: \(done.val)
        다음 순서로 쓰세요: 1) 왜 틀렸는지(철자, 시제, 단수/복수, 뜻 혼동 등) 2) 올바르게 완성한 문장 3) 같은 실수를 피하는 짧은 팁
        """
        let stillHere = { [weak self] in self?.quiz?.sid == sid && self?.quiz?.i == idx }
        do {
            let text = try await client.stream(messages: [.init(role: .user, text: prompt)]) { [weak self] partial in
                guard stillHere() else { return }
                self?.quiz?.explanation = partial
            }
            if stillHere() { quiz?.explanation = text }
        } catch {
            if stillHere() { quiz?.explanation = (error as? LocalizedError)?.errorDescription ?? "AI 응답에 실패했어요." }
        }
        if stillHere() { quiz?.explaining = false }
    }
}

extension JSONEncoder {
    static let app: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .millisecondsSince1970
        return e
    }()
}

extension JSONDecoder {
    static let app: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .millisecondsSince1970
        return d
    }()
}
