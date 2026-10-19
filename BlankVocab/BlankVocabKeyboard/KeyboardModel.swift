import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class KeyboardModel {
    enum Lang: String { case ko, en }
    enum Page { case letters, numbers, symbols }

    // 자판 상태
    var lang: Lang = .ko {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "kb.lang") }
    }
    var page: Page = .letters
    var shift = false
    var capsLock = false
    var needsGlobe = true
    var hasFullAccess = false
    var returnLabel = "return"

    /// 커서 앞 단어 (상단 바에서 "뜻 보기" 바로가기로 보여 줌)
    var currentWord = ""

    // 사전 상태
    var dictOpen = false
    var query = ""
    var dictLang: NaverDict.Lang = .enko {
        didSet { UserDefaults.standard.set(dictLang.rawValue, forKey: "kb.dictLang") }
    }
    var results: [NaverDict.Entry] = []
    var searchedQuery = ""
    var loading = false
    var errorText: String?
    var insertedWord: String?

    static let keysHeight: CGFloat = 216
    static let barHeight: CGFloat = 44
    static let resultsHeight: CGFloat = 190

    var preferredHeight: CGFloat {
        Self.keysHeight + Self.barHeight + (dictOpen ? Self.resultsHeight : 0)
    }

    @ObservationIgnored weak var controller: KeyboardViewController?
    @ObservationIgnored private var composer = HangulComposer()
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var lastShiftTap = Date.distantPast

    init() {
        if let raw = UserDefaults.standard.string(forKey: "kb.lang"), let l = Lang(rawValue: raw) { lang = l }
        if let raw = UserDefaults.standard.string(forKey: "kb.dictLang"), let l = NaverDict.Lang(rawValue: raw) { dictLang = l }
    }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }

    // MARK: - 입력 대상 (문서 또는 사전 검색창)

    private var contextBefore: String {
        dictOpen ? query : (proxy?.documentContextBeforeInput ?? "")
    }

    private func targetInsert(_ s: String) {
        guard !s.isEmpty else { return }
        if dictOpen {
            query += s
            querySearchSoon()
        } else {
            proxy?.insertText(s)
        }
    }

    private func targetDelete(search: Bool = true) {
        if dictOpen {
            if !query.isEmpty { query.removeLast() }
            if search { querySearchSoon() }
        } else {
            proxy?.deleteBackward()
        }
    }

    /// 사용자가 커서를 옮기는 등 조합 중이던 글자가 사라졌으면 조합 상태를 버린다.
    private func syncComposer() {
        let c = composer.composing
        if !c.isEmpty && !contextBefore.hasSuffix(c) { composer.reset() }
    }

    // MARK: - 키 동작

    func letterTitle(_ key: String) -> String {
        switch lang {
        case .en: return (shift || capsLock) ? key.uppercased() : key
        case .ko: return (shift || capsLock) ? (Self.koShift[key] ?? key) : key
        }
    }

    static let koShift: [String: String] = [
        "ㅂ": "ㅃ", "ㅈ": "ㅉ", "ㄷ": "ㄸ", "ㄱ": "ㄲ", "ㅅ": "ㅆ", "ㅐ": "ㅒ", "ㅔ": "ㅖ",
    ]

    func tapLetter(_ key: String) {
        let s = page == .letters ? letterTitle(key) : key
        if page == .letters, lang == .ko, HangulComposer.isJamo(s), let ch = s.first {
            syncComposer()
            let hadComposing = !composer.composing.isEmpty
            let r = composer.input(ch)
            if hadComposing { targetDelete(search: false) }
            targetInsert(r.commit + r.composing)
        } else {
            composer.reset()
            targetInsert(s)
        }
        if shift && !capsLock { shift = false }
        afterEdit()
    }

    func tapBackspace() {
        syncComposer()
        if !composer.isEmpty {
            let rest = composer.backspace()
            targetDelete(search: false)
            if rest.isEmpty {
                if dictOpen { querySearchSoon() }
            } else {
                targetInsert(rest)
            }
        } else {
            targetDelete()
        }
        afterEdit()
    }

    func tapSpace() {
        composer.reset()
        targetInsert(" ")
        afterEdit()
    }

    func tapReturn() {
        composer.reset()
        if dictOpen {
            searchNow()
        } else {
            proxy?.insertText("\n")
            afterEdit()
        }
    }

    func tapShift() {
        let now = Date()
        if capsLock {
            capsLock = false
            shift = false
        } else if shift && now.timeIntervalSince(lastShiftTap) < 0.35 {
            capsLock = true
        } else {
            shift.toggle()
        }
        lastShiftTap = now
    }

    func toggleLang() {
        composer.reset()
        lang = (lang == .ko) ? .en : .ko
        page = .letters
        shift = false
        capsLock = false
    }

    func setPage(_ p: Page) {
        composer.reset()
        page = p
    }

    func nextKeyboard() {
        composer.reset()
        controller?.advanceToNextInputMode()
    }

    private func afterEdit() {
        if !dictOpen { refreshContext() }
    }

    /// 문서가 바뀌었을 때 (키보드 컨트롤러가 호출)
    func refreshContext() {
        guard let proxy else { return }
        if let sel = proxy.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines), !sel.isEmpty, sel.count <= 40 {
            currentWord = sel
        } else {
            currentWord = Self.lastWord(in: proxy.documentContextBeforeInput ?? "")
        }
        returnLabel = Self.returnTitle(proxy.returnKeyType)
    }

    static func lastWord(in text: String) -> String {
        // 커서 바로 앞의 단어 (공백·문장부호로 끊음). 끝이 공백이면 그 앞 단어.
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols)
        let trimmed = text.trimmingCharacters(in: separators)
        guard let piece = trimmed.components(separatedBy: separators).last else { return "" }
        return piece.count <= 40 ? piece : ""
    }

    static func returnTitle(_ type: UIReturnKeyType?) -> String {
        switch type ?? .default {
        case .go: "이동"
        case .search, .google, .yahoo: "검색"
        case .send: "보내기"
        case .done: "완료"
        case .next: "다음"
        case .join: "가입"
        case .route: "경로"
        case .continue: "계속"
        default: "return"
        }
    }

    // MARK: - 사전

    func openDictionary(prefill: String? = nil) {
        composer.reset()
        let word = prefill ?? currentWord
        query = word
        results = []
        searchedQuery = ""
        errorText = nil
        insertedWord = nil
        dictOpen = true
        controller?.updateHeight()
        if !word.isEmpty { searchNow() }
    }

    func closeDictionary() {
        composer.reset()
        searchTask?.cancel()
        dictOpen = false
        loading = false
        controller?.updateHeight()
        refreshContext()
    }

    func clearQuery() {
        composer.reset()
        query = ""
        results = []
        searchedQuery = ""
        errorText = nil
        searchTask?.cancel()
        loading = false
    }

    func setDictLang(_ l: NaverDict.Lang) {
        guard l != dictLang else { return }
        dictLang = l
        searchNow()
    }

    /// 사전 결과의 단어를 문서에 넣는다.
    func insertIntoDocument(_ word: String) {
        proxy?.insertText(word)
        insertedWord = word
    }

    private func querySearchSoon() {
        searchTask?.cancel()
        let q = query
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await self?.runSearch(q)
        }
    }

    func searchNow() {
        searchTask?.cancel()
        let q = query
        searchTask = Task { [weak self] in await self?.runSearch(q) }
    }

    private func runSearch(_ q: String) async {
        let text = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            results = []
            searchedQuery = ""
            errorText = nil
            loading = false
            return
        }
        guard hasFullAccess else {
            loading = false
            return
        }
        loading = true
        errorText = nil
        do {
            let found = try await NaverDict.search(text, lang: dictLang)
            guard !Task.isCancelled else { return }
            results = found
            searchedQuery = text
            loading = false
        } catch is CancellationError {
            // 새 검색으로 바뀜
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            searchedQuery = text
            errorText = (error as? LocalizedError)?.errorDescription ?? "인터넷 연결을 확인해 주세요."
            loading = false
        }
    }
}
