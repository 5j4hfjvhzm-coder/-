import SwiftUI

/// 키보드 위쪽에 펼쳐지는 사전 패널.
/// 사전이 열려 있는 동안 자판으로 친 글자는 문서가 아니라 이 검색창으로 들어간다.
struct DictionaryPanel: View {
    let model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .frame(height: KeyboardModel.barHeight)
            results
                .frame(height: KeyboardModel.resultsHeight)
                .background(KB.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
        }
    }

    // MARK: 검색창

    private var searchBar: some View {
        HStack(spacing: 6) {
            Button {
                model.closeDictionary()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(KB.ink)
                    .frame(width: 34, height: 34)
                    .background(KB.special, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .accessibilityLabel("사전 닫기")

            HStack(spacing: 6) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(KB.accent)
                if model.query.isEmpty {
                    Text("찾을 단어를 입력하세요")
                        .foregroundStyle(KB.sub)
                        .lineLimit(1)
                } else {
                    Text(model.query)
                        .foregroundStyle(KB.ink)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Caret()
                Spacer(minLength: 0)
                if !model.query.isEmpty {
                    Button {
                        model.clearQuery()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(KB.sub)
                    }
                    .accessibilityLabel("지우기")
                }
            }
            .font(.system(size: 16))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(KB.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 0) {
                ForEach(NaverDict.Lang.allCases, id: \.self) { l in
                    Button {
                        model.setDictLang(l)
                    } label: {
                        Text(l.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(model.dictLang == l ? Color.white : KB.ink)
                            .frame(width: 40, height: 30)
                            .background(model.dictLang == l ? KB.accent : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            .padding(2)
            .background(KB.special.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 6)
    }

    // MARK: 결과

    @ViewBuilder
    private var results: some View {
        if !model.hasFullAccess {
            message(icon: "lock.fill",
                    text: "사전을 쓰려면 인터넷 연결이 필요해요.\n설정 › 일반 › 키보드 › 키보드 › 빈칸 단어장 키보드 › '전체 접근 허용'을 켜 주세요.")
        } else if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
            message(icon: "character.book.closed",
                    text: "자판으로 단어를 입력하면 네이버 사전에서 찾아 줘요.\n한/영 키로 입력 언어를 바꿀 수 있어요.")
        } else if model.loading && model.results.isEmpty {
            VStack { ProgressView() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = model.errorText {
            message(icon: "exclamationmark.triangle", text: err)
        } else if model.results.isEmpty {
            if model.searchedQuery.isEmpty {
                VStack { ProgressView() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                message(icon: "magnifyingglass", text: "“\(model.searchedQuery)” 검색 결과가 없어요.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.results) { entry in
                        EntryRow(entry: entry, inserted: model.insertedWord == entry.word) {
                            model.insertIntoDocument(entry.word)
                        }
                        Divider().opacity(0.5)
                    }
                    Text("출처: 네이버 사전")
                        .font(.system(size: 11))
                        .foregroundStyle(KB.sub)
                        .padding(10)
                }
            }
            .overlay(alignment: .topTrailing) {
                if model.loading {
                    ProgressView().controlSize(.small).padding(8)
                }
            }
        }
    }

    private func message(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(KB.accent)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(KB.sub)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EntryRow: View {
    let entry: NaverDict.Entry
    let inserted: Bool
    let onInsert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.word)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(KB.ink)
                if let sup = entry.superscript {
                    Text(sup).font(.system(size: 11)).foregroundStyle(KB.sub)
                }
                if let ph = entry.phonetic {
                    Text(ph)
                        .font(.system(size: 12))
                        .foregroundStyle(KB.sub)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Button(action: onInsert) {
                    Label(inserted ? "입력됨" : "입력", systemImage: inserted ? "checkmark" : "arrow.down.to.line")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KB.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(KB.accent.opacity(0.12), in: Capsule())
                }
                .accessibilityLabel("\(entry.word) 문서에 입력")
            }

            ForEach(Array(entry.groups.prefix(3).enumerated()), id: \.offset) { _, g in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let pos = g.partOfSpeech {
                        Text(pos)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(KB.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(KB.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    }
                    Text(meansText(g.means))
                        .font(.system(size: 14))
                        .foregroundStyle(KB.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let source = entry.source {
                Text(source)
                    .font(.system(size: 10))
                    .foregroundStyle(KB.sub)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func meansText(_ means: [String]) -> String {
        let list = means.prefix(3)
        if list.count == 1 { return list[list.startIndex] }
        return list.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "  ")
    }
}

/// 깜빡이는 커서
private struct Caret: View {
    @State private var on = true

    var body: some View {
        Rectangle()
            .fill(KB.accent)
            .frame(width: 2, height: 20)
            .opacity(on ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) { on = false }
            }
    }
}
