import SwiftUI

/// 단어 하나의 전체 뜻, 발음기호, 발음 듣기, ★ 저장
struct EntryDetailView: View {
    @Environment(Store.self) private var store
    let entry: NaverDict.Entry

    #if os(iOS)
    private static let titleFont = Font.largeTitle.bold()
    #else
    private static let titleFont = Font.title3.bold()
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(entry.word)
                        .font(Self.titleFont)
                        .minimumScaleFactor(0.6)
                    if let sup = entry.superscript {
                        Text(sup)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let phonetic = entry.phonetic {
                    Text(phonetic)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        Speech.shared.say(entry.word)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .accessibilityLabel("발음 듣기")

                    Button {
                        store.toggleSave(entry)
                    } label: {
                        Image(systemName: store.isSaved(entry) ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                    }
                    .accessibilityLabel(store.isSaved(entry) ? "단어장에서 빼기" : "단어장에 저장")
                }

                if entry.groups.isEmpty {
                    Text("뜻 정보가 없어요")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(entry.groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 3) {
                        if let pos = group.partOfSpeech {
                            Text(pos)
                                .font(.caption2.bold())
                                .foregroundStyle(Color.accentColor)
                        }
                        ForEach(Array(group.means.enumerated()), id: \.offset) { i, mean in
                            Text(group.means.count > 1 ? "\(i + 1). \(mean)" : mean)
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 2)
                }

                Text(entry.source.map { "출처: \($0) · 네이버 사전" } ?? "출처: 네이버 사전")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            #if os(iOS)
            .padding()
            #endif
        }
        .navigationTitle(entry.word)
    }
}
