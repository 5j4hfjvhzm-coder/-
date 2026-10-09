import SwiftUI
import UIKit

struct DictSelection: Equatable {
    var key: String
    var entry: Entry
    var sense: Sense
    /// 숙어로 고른 경우 문장 속 모양 (pick it up)
    var phraseSurface: String?
}

/// 사전 조회 결과 목록. onSelect 가 있으면 뜻을 탭해서 고르고, 다시 탭하면 해제한다.
struct DictionaryView: View {
    let result: LookupResult
    /// 고른 뜻들 (여러 개)
    var selectedKeys: Set<String> = []
    var onSelect: ((DictSelection) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let surface = result.surface.lowercased()
            let otherLemmas = result.lemmas.filter { $0 != surface }
            if !otherLemmas.isEmpty {
                Text("기본형: \(otherLemmas.joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !result.guessedPos.isEmpty {
                Text("앞 단어로 추정한 품사: \(result.guessedPos.map { posKorean[$0] ?? $0 }.joined(separator: " / ")) → 위로 정렬")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if result.phrases.isEmpty && result.entries.isEmpty {
                Text("사전에 없는 단어예요.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }

            if !result.phrases.isEmpty {
                SectionTitle("숙어·구동사")
                ForEach(result.phrases) { p in
                    HStack(alignment: .firstTextBaseline) {
                        Text(p.match.phrase).font(.title3.bold())
                        if p.surface.lowercased() != p.match.phrase {
                            Text("← “\(p.surface)”").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(p.entries) { e in
                        EntryCard(entry: e, selectedKeys: selectedKeys, onSelect: handler(phraseSurface: p.surface))
                    }
                }
                if !result.entries.isEmpty { SectionTitle("단어") }
            }

            ForEach(result.entries) { e in
                EntryCard(entry: e, selectedKeys: selectedKeys, onSelect: handler(phraseSurface: nil))
            }
        }
    }
}

extension DictionaryView {
    private func handler(phraseSurface: String?) -> ((Entry, Sense, String) -> Void)? {
        guard let onSelect else { return nil }
        return { entry, sense, key in
            onSelect(DictSelection(key: key, entry: entry, sense: sense, phraseSurface: phraseSurface))
        }
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote.bold())
            .foregroundStyle(Color.accentColor)
            .padding(.top, 8)
    }
}

private struct EntryCard: View {
    let entry: Entry
    let selectedKeys: Set<String>
    let onSelect: ((Entry, Sense, String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.word).font(.headline)
                Badge(label: posKorean[entry.pos] ?? entry.pos, tone: .blue)
                Badge(label: entry.source == .ko ? "영한" : "영영")
                if let ipa = entry.ipa {
                    Text(ipa).font(.caption).foregroundStyle(.secondary)
                }
            }
            if !entry.ko.isEmpty {
                Text(entry.ko.joined(separator: ", ")).font(.subheadline).foregroundStyle(.blue)
            }
            ForEach(Array(entry.senses.enumerated()), id: \.element.id) { i, s in
                let key = "\(entry.source.rawValue):\(entry.id):\(s.id)"
                let selected = selectedKeys.contains(key)
                Button {
                    onSelect?(entry, s, key)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1)").font(.subheadline.bold()).foregroundStyle(.secondary).frame(width: 16)
                        VStack(alignment: .leading, spacing: 3) {
                            TagBadges(tags: s.tags)
                            Text(s.gloss).font(.body).foregroundStyle(.primary)
                            if !s.ko.isEmpty {
                                Text(s.ko.joined(separator: ", ")).font(.subheadline).foregroundStyle(.blue)
                            }
                            if let ex = s.examples.first {
                                Text(ex.ko.map { "\(ex.text)\n\($0)" } ?? ex.text)
                                    .font(.footnote).italic().foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        if selected {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .padding(6)
                    .background(selected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onSelect == nil)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
