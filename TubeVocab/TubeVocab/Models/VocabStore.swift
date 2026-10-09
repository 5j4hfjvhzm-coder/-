import Foundation
import Observation

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

    var target: BlankTarget { BlankTarget(surface: surface, lemma: lemma, forms: forms) }
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
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([SavedWord].self, from: data) {
            words = list
        }
        highlight = buildHighlightIndex(words.map(\.target))
    }

    func add(_ w: SavedWord) {
        words.insert(w, at: 0)
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
        do {
            let data = try JSONEncoder().encode(words)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("단어장 저장 실패: \(error)")
        }
    }
}
