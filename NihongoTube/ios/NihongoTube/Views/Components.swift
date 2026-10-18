import SwiftUI
import UIKit

/// 단어마다 탭할 수 있는 일본어 문장. 저장한 단어는 노란 형광펜.
/// 단어 하나하나를 링크로 만들고 openURL 로 받아서, 줄바꿈이 자연스러운 Text 하나로 그린다.
struct TappableText: View {
    let text: String
    var highlight: HighlightIndex? = nil
    /// 단어(링크) 글자색. 영상 위 자막처럼 어두운 배경이면 .white
    var textColor: Color = .primary
    /// 누른 단어의 문장 안 글자 위치
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        Text(Self.build(text, highlight: highlight, tappable: onTap != nil))
            .tint(textColor)
            .foregroundStyle(textColor)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "ntword", let i = Int(url.host() ?? ""), let onTap {
                    onTap(i)
                }
                return .handled
            })
    }

    static func build(_ text: String, highlight: HighlightIndex?, tappable: Bool) -> AttributedString {
        let marks = highlight.map { highlightMarks(text, $0) } ?? []
        var out = AttributedString()
        for seg in segmentJapanese(text) {
            var piece = AttributedString(seg.text)
            if seg.isWord && tappable {
                piece.link = URL(string: "ntword://\(seg.start)")
            }
            let end = min(marks.count, seg.start + seg.text.count)
            if seg.start < end, marks[seg.start..<end].contains(true) {
                piece.backgroundColor = Color.yellow.opacity(0.55)
            }
            out.append(piece)
        }
        return out
    }
}

struct Badge: View {
    let label: String
    var tone: Color = .secondary

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tone.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}

extension View {
    /// 아이패드처럼 넓은 화면에서 글줄이 너무 길어지지 않게 가운데로 모은다
    func readableWidth(_ max: CGFloat = 760) -> some View {
        frame(maxWidth: max).frame(maxWidth: .infinity)
    }
}
