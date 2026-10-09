import SwiftUI
import UIKit

/// 단어마다 탭할 수 있는 문장. 저장한 단어는 노란 형광펜.
/// 단어 하나하나를 링크로 만들고 openURL 로 받아서, 줄바꿈이 자연스러운 Text 하나로 그린다.
struct TappableText: View {
    let text: String
    var highlight: HighlightIndex? = nil
    /// (단어 인덱스, 문장의 단어 목록)
    var onTap: ((Int, [String]) -> Void)? = nil

    var body: some View {
        let built = Self.build(text, highlight: highlight, tappable: onTap != nil)
        Text(built.attributed)
            .tint(.primary)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "tvword", let i = Int(url.host() ?? ""), let onTap {
                    onTap(i, built.words)
                }
                return .handled
            })
    }

    static func build(_ text: String, highlight: HighlightIndex?, tappable: Bool) -> (attributed: AttributedString, words: [String]) {
        let toks = tokenize(text)
        let marks = highlight.map { highlightTokens(toks, $0) } ?? Array(repeating: false, count: toks.count)
        var out = AttributedString()
        var words: [String] = []
        for (i, t) in toks.enumerated() {
            var piece = AttributedString(t.text)
            if t.isWord {
                if tappable { piece.link = URL(string: "tvword://\(words.count)") }
                words.append(t.text)
            }
            // 하이라이트된 두 단어 사이 공백도 칠한다 (gave up)
            let between = !t.isWord && i > 0 && i + 1 < toks.count && marks[i - 1] && marks[i + 1]
                && t.text.allSatisfy(\.isWhitespace)
            if marks[i] || between {
                piece.backgroundColor = Color.yellow.opacity(0.55)
            }
            out.append(piece)
        }
        return (out, words)
    }
}

struct Badge: View {
    let label: String
    var strong = false
    var tone: Color = .secondary

    var body: some View {
        Text(label)
            .font(.caption2.weight(strong ? .heavy : .semibold))
            .foregroundStyle(strong ? Color.red : tone)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((strong ? Color.red : tone).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}

/// 속어·비격식 같은 태그 배지
struct TagBadges: View {
    let tags: [String]

    var body: some View {
        let labels = tagLabels(tags)
        if !labels.isEmpty {
            HStack(spacing: 4) {
                ForEach(labels, id: \.self) { t in
                    Badge(label: t.label, strong: t.strong)
                }
            }
        }
    }
}
