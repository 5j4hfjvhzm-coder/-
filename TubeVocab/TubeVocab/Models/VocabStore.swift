import Foundation
import Observation

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
    var stage: Int = 0
    /// 저장 직후 바로 시험에 나오게
    var dueAt: Int = nowMs()
    var correct: Int = 0
    var wrong: Int = 0
    /// 고른 뜻들 (예전에 저장한 단어는 nil → sense/senseKo 하나만)
    var meanings: [Meaning]? = nil

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

/// 단어장. Documents/words.json 에 저장.
@MainActor
@Observable
final class VocabStore {
    private(set) var words: [SavedWord] = []
    private(set) var highlight = HighlightIndex()
    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = URL.documentsDirectory.appending(path: "words.json")) {
        self.fileURL = fileURL
        var loadedCount = 0
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([SavedWord].self, from: data) {
            loadedCount = list.count
            words = SavedWord.mergeDuplicates(list)
        }
        highlight = buildHighlightIndex(words.map(\.target))
        // 예전 버전에서 뜻마다 따로 저장된 단어를 하나로 합쳤으면 바로 저장
        if words.count < loadedCount { save() }
    }

    /// 저장. 같은 단어를 같은 문장에서 이미 저장했으면 뜻만 합친다.
    func add(_ w: SavedWord) {
        if let i = words.firstIndex(where: { $0.mergeKey == w.mergeKey }) {
            words[i].absorb(w)
        } else {
            words.insert(w, at: 0)
        }
        changed()
    }

    func remove(id: UUID) {
        words.removeAll { $0.id == id }
        changed()
    }

    func word(id: UUID) -> SavedWord? {
        words.first { $0.id == id }
    }

    func answer(id: UUID, correct: Bool) {
        guard let i = words.firstIndex(where: { $0.id == id }) else { return }
        let next = review(SrsState(stage: words[i].stage, dueAt: words[i].dueAt), correct: correct, now: nowMs())
        words[i].stage = next.stage
        words[i].dueAt = next.dueAt
        if correct { words[i].correct += 1 } else { words[i].wrong += 1 }
        changed()
    }

    private func changed() {
        highlight = buildHighlightIndex(words.map(\.target))
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(words)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("단어장 저장 실패: \(error)")
        }
    }
}
