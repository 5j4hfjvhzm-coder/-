import Foundation
import Observation

func nowMs() -> Int {
    Int(Date().timeIntervalSince1970 * 1000)
}

/// 저장한 뜻 하나
struct Meaning: Codable, Hashable {
    /// 한국어 단어 (먹다)
    var ko: String
    /// 한국어 뜻풀이
    var def: String
    /// 이 뜻의 일본어 읽기
    var reading: String
}

/// 저장한 모르는 단어 하나
struct SavedWord: Codable, Identifiable, Hashable {
    var id = UUID()
    /// 문장 속 모양 (食べました)
    var surface: String
    /// 기본형 (食べる)
    var term: String
    /// 대표 읽기 (たべる)
    var reading: String
    /// 사전에 나온 읽기들 (정답 인정용)
    var readings: [String]
    var meanings: [Meaning]
    /// 원문 일본어 문장
    var sentence: String
    var sentenceKo: String
    /// 문장 안 시작 글자 위치
    var start: Int
    var videoId: String
    var timeMs: Int
    var createdAt: Int = nowMs()
    var correct: Int = 0
    var wrong: Int = 0
    var starred: Bool? = nil
    var updatedAt: Int? = nil

    var star: Bool { starred ?? false }
    var modified: Int { updatedAt ?? createdAt }

    var target: BlankTarget { BlankTarget(surface: surface, term: term, readings: readings, start: start) }

    /// "먹다, 먹고살다" 처럼 고른 뜻을 한 줄로
    var summary: String {
        uniqued(meanings.map(\.ko)).joined(separator: ", ")
    }

    /// 같은 단어를 같은 문장에서 다시 저장하면 하나로 합친다
    var mergeKey: String { "\(term)|\(videoId)|\(sentence)" }

    /// 다른 저장분의 뜻을 이쪽에 합친다 (시험 기록은 이쪽 것 유지)
    mutating func absorb(_ other: SavedWord) {
        meanings = uniqued(meanings + other.meanings)
        readings = uniqued(readings + other.readings)
    }

    /// 같은 단어·같은 문장으로 따로 저장된 것들을 하나로 (먼저 저장한 것 기준)
    static func mergeDuplicates(_ list: [SavedWord]) -> [SavedWord] {
        var order: [String] = []
        var byKey: [String: SavedWord] = [:]
        for w in list.reversed() {
            if var existing = byKey[w.mergeKey] {
                existing.absorb(w)
                byKey[w.mergeKey] = existing
            } else {
                byKey[w.mergeKey] = w
                order.append(w.mergeKey)
            }
        }
        return order.reversed().compactMap { byKey[$0] }
    }
}

/// 단어장. Documents/words.json 에 저장 (지운 단어 기록은 deleted.json, 동기화용).
@MainActor
@Observable
final class VocabStore {
    private(set) var words: [SavedWord] = []
    private(set) var highlight = HighlightIndex()
    /// 지운 단어 id → 지운 시각(ms). 다른 기기에도 지운 것을 알려 주기 위해 보관.
    private(set) var deleted: [String: Int] = [:]
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let deletedURL: URL
    /// 이 기기에서 단어장이 바뀌면 불린다 (동기화 예약)
    @ObservationIgnored var onLocalChange: (@MainActor () -> Void)?

    init(fileURL: URL = URL.documentsDirectory.appending(path: "words.json")) {
        self.fileURL = fileURL
        self.deletedURL = fileURL.deletingLastPathComponent()
            .appending(path: fileURL.deletingPathExtension().lastPathComponent + "-deleted.json")
        var loadedCount = 0
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([SavedWord].self, from: data) {
            loadedCount = list.count
            words = list
        }
        if let data = try? Data(contentsOf: deletedURL),
           let map = try? JSONDecoder().decode([String: Int].self, from: data) {
            deleted = map
        }
        normalize()
        highlight = buildHighlightIndex(words.map(\.target))
        // 예전 버전에서 뜻마다 따로 저장된 단어를 하나로 합쳤으면 바로 저장
        if words.count < loadedCount { save() }
    }

    /// 같은 단어·같은 문장 합치기 + 최근 저장 순 정렬. 합쳐져 사라진 id 는 지운 것으로 기록.
    private func normalize() {
        let before = Set(words.map(\.id))
        words = SavedWord.mergeDuplicates(words).sorted { $0.createdAt > $1.createdAt }
        let after = Set(words.map(\.id))
        let now = nowMs()
        for id in before.subtracting(after) { deleted[id.uuidString] = now }
    }

    /// 저장. 같은 단어를 같은 문장에서 이미 저장했으면 뜻만 합친다.
    func add(_ w: SavedWord) {
        var w = w
        w.updatedAt = nowMs()
        if let i = words.firstIndex(where: { $0.mergeKey == w.mergeKey }) {
            // 같은 문장에서 다시 저장하면 고른 뜻으로 바꾼다
            words[i].meanings = w.meanings
            words[i].readings = uniqued(words[i].readings + w.readings)
            words[i].updatedAt = nowMs()
        } else {
            words.insert(w, at: 0)
        }
        changed()
    }

    func remove(id: UUID) {
        words.removeAll { $0.id == id }
        deleted[id.uuidString] = nowMs()
        changed()
    }

    func word(id: UUID) -> SavedWord? {
        words.first { $0.id == id }
    }

    /// 이 문장에서 이 단어를 저장했는지
    func saved(term: String, sentence: String, videoId: String) -> SavedWord? {
        words.first { $0.mergeKey == "\(term)|\(videoId)|\(sentence)" }
    }

    /// 시험 결과 기록 (맞힘/틀림 횟수)
    func recordAnswer(id: UUID, correct: Bool) {
        guard let i = words.firstIndex(where: { $0.id == id }) else { return }
        if correct { words[i].correct += 1 } else { words[i].wrong += 1 }
        words[i].updatedAt = nowMs()
        changed()
    }

    /// ★ 헷갈리는 단어 표시 켜고 끄기
    func toggleStar(id: UUID) {
        guard let i = words.firstIndex(where: { $0.id == id }) else { return }
        words[i].starred = !words[i].star
        words[i].updatedAt = nowMs()
        changed()
    }

    /// 동기화 결과로 통째로 바꾸기 (이 경우엔 다시 동기화를 예약하지 않는다)
    func replaceFromSync(words newWords: [SavedWord], deleted newDeleted: [String: Int]) {
        words = newWords
        deleted = newDeleted
        normalize()
        highlight = buildHighlightIndex(words.map(\.target))
        save()
    }

    private func changed() {
        highlight = buildHighlightIndex(words.map(\.target))
        save()
        onLocalChange?()
    }

    private func save() {
        do {
            try JSONEncoder().encode(words).write(to: fileURL, options: .atomic)
            try JSONEncoder().encode(deleted).write(to: deletedURL, options: .atomic)
        } catch {
            print("단어장 저장 실패: \(error)")
        }
    }
}
