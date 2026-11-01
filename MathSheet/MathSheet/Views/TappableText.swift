import SwiftUI
import UIKit

/// 영어 문장. 단어를 누르면 한국어 뜻이 말풍선으로 나와요.
struct TappableText: View {
    let text: String
    var font: Font = .title3

    @State private var lookup: WordLookup?

    var body: some View {
        Text(Self.linked(text))
            .font(font)
            .tint(.primary)   // 링크를 파란색 대신 보통 글자색으로
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "mathword",
                      let word = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "w" })?.value
                else { return .systemAction }
                lookup = WordLookup(word: word)
                return .handled
            })
            .popover(item: $lookup) { item in
                WordPopover(word: item.word)
                    .presentationCompactAdaptation(.popover)
            }
    }

    /// 단어마다 누를 수 있는 링크를 달아요. (AB, DEF 같은 점 이름은 빼요)
    static func linked(_ s: String) -> AttributedString {
        var out = AttributedString()
        var word = ""
        var other = ""

        func flushOther() {
            if !other.isEmpty { out += AttributedString(other); other = "" }
        }
        func flushWord() {
            guard !word.isEmpty else { return }
            var trailing = ""
            while word.hasSuffix("'") { word.removeLast(); trailing += "'" }
            let tappable = (word.count > 1 && word != word.uppercased()) || word == "a"
            var piece = AttributedString(word)
            if tappable {
                var c = URLComponents()
                c.scheme = "mathword"
                c.host = "word"
                c.queryItems = [URLQueryItem(name: "w", value: word)]
                piece.link = c.url
            }
            out += piece
            if !trailing.isEmpty { out += AttributedString(trailing) }
            word = ""
        }

        for ch in s {
            let isWordChar = (ch.isASCII && ch.isLetter) || ((ch == "'" || ch == "’") && !word.isEmpty)
            if isWordChar {
                flushOther()
                word.append(ch == "’" ? "'" : ch)
            } else {
                flushWord()
                other.append(ch)
            }
        }
        flushWord()
        flushOther()
        return out
    }
}

struct WordLookup: Identifiable {
    let id = UUID()
    let word: String
}

struct WordPopover: View {
    let word: String
    @State private var showDictionary = false

    var body: some View {
        let found = Glossary.lookup(word)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(found?.word ?? word.lowercased())
                    .font(.title2.bold())
                Spacer()
                Button { Speech.shared.say(word) } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .accessibilityLabel("단어 읽어주기")
            }
            if let m = found?.meaning {
                Text(m)
                    .font(.title3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("단어장에 없는 단어예요.")
                    .foregroundStyle(.secondary)
            }
            if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word) {
                Button("iPad 사전에서 더 보기") { showDictionary = true }
                    .font(.callout)
            }
        }
        .padding()
        .frame(minWidth: 260, maxWidth: 380, alignment: .leading)
        .sheet(isPresented: $showDictionary) {
            DictionaryView(term: word)
        }
    }
}

/// iPad 내장 사전 (설정에서 영한사전을 받아 두면 영한 뜻이 나와요)
struct DictionaryView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ vc: UIReferenceLibraryViewController, context: Context) {}
}
