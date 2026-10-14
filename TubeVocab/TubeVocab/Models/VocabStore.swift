import Foundation
import Observation

func nowMs() -> Int {
    Int(Date().timeIntervalSince1970 * 1000)
}

/// 저장한 뜻 하나
struct Meaning: Codable, Hashable {
    /// 사전 뜻풀이 (영한 사전이면 한국어, 영영 사전이면 영어)
    var gloss: String
    /// 한국어 뜻 (영한 사전이면 gloss 와 같음)
    var ko: String
    var tags: [String]
    var pos: String

    /// 목록에 보여 줄 짧은 뜻: 한국어가 있으면 한국어
    var short: String { ko.isEmpty ? gloss : ko }
}

/// 저장한 모르는 단어 하나
struct SavedWord: Codable, Identifiable, Hashable {
    var id = UUID()
    /// 문장 속 모양 (gave up / went)
    var surface: String
    /// 기본형/표제어 (give up / go)
    var lemma: String
    /// 활용형 (정답 인정·하이라이트용)
    var forms: [String]
    var pos: String
    /// 고른 뜻
    var sense: String
    var senseTags: [String]
    /// 고른 뜻의 한국어 (있으면)
    var senseKo: String
    var sentenceEn: String
    var sentenceKo: String
    var videoId: String
    var timeMs: Int
    var createdAt: Int = nowMs()
    /// 예전 간격 반복 기록. 지금은 쓰지 않지만 저장 파일 호환을 위해 남겨 둔다.
    var stage: Int = 0
    var dueAt: Int = nowMs()
    var correct: Int = 0
    var wrong: Int = 0
    /// 고른 뜻들 (예전에 저장한 단어는 nil → sense/senseKo 하나만)
    var meanings: [Meaning]? = nil
    /// ★ 헷갈리는 단어 (예전 파일에는 없으므로 옵셔널)
    var starred: Bool? = nil
    /// 마지막으로 바뀐 시각 (동기화 때 더 최근 것을 고른다). 예전 파일에는 없음.
    var updatedAt: Int? = nil

    var star: Bool { starred ?? false }
    var modified: Int { updatedAt ?? createdAt }

    var target: BlankTarget { BlankTarget(surface: surface, lemma: lemma, forms: forms) }

    var allMeanings: [Meaning] {
        meanings ?? [Meaning(gloss: sense, ko: senseKo, tags: senseTags, pos: pos)]
    }

    /// "5월, 아마" 처럼 고른 뜻을 한 줄로
    var summary: String {
        uniqued(allMeanings.map(\.short)).joined(separator: ", ")
    }

    /// 같은 단어를 같은 문장에서 다시 저장하면 하나로 합친다
    var mergeKey: String { "\(lemma)|\(videoId)|\(sentenceEn)" }

    /// 뜻 목록을 바꾸고 요약 필드(sense, senseKo, senseTags)도 맞춘다
    mutating func setMeanings(_ list: [Meaning]) {
        let list = uniqued(list)
        meanings = list
        sense = list.map(\.gloss).joined(separator: " / ")
        senseKo = uniqued(list.map(\.ko).filter { !$0.isEmpty }).joined(separator: ", ")
        senseTags = uniqued(list.flatMap(\.tags))
        if let first = list.first { pos = first.pos }
    }

    /// 다른 저장분의 뜻·활용형을 이쪽에 합친다 (복습 기록은 이쪽 것 유지)
    mutating func absorb(_ other: SavedWord) {
        setMeanings(allMeanings + other.allMeanings)
        forms = uniqued(forms + other.forms)
    }

    /// 단어장 정리: 같은 단어·같은 문장으로 따로 저장된 것들을 하나로 (먼저 저장한 것 기준)
    static func mergeDuplicates(_ list: [SavedWord]) -> [SavedWord] {
        var order: [String] = []
        var byKey: [String: SavedWord] = [:]
        // 목록은 최근 것이 앞이므로 뒤(오래된 것)부터 합친다
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
            words[i].absorb(w)
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
