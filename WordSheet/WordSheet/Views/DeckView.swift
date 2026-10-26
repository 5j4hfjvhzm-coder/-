import SwiftUI

enum DeckFilter: Hashable {
    case all, marked, color(Marker)
}

/// 단어장 한 권: 단어 가리기 / 뜻 가리기 / 형광펜
struct DeckView: View {
    @EnvironmentObject private var store: Store
    let deckID: String

    @AppStorage("hideWord") private var hideWord = false
    @AppStorage("hideMeaning") private var hideMeaning = false
    @AppStorage("fontSize") private var fontSize = 24.0

    @State private var markerMode = false
    /// nil이면 지우개
    @State private var pen: Marker? = .yellow
    /// 가린 상태에서 탭해서 잠깐 펼친 단어
    @State private var revealed: Set<String> = []
    @State private var filter: DeckFilter = .all
    @State private var search = ""
    @State private var confirmClear = false
    /// 섞었을 때 단어 id → 순서. nil이면 원래 순서
    @State private var shuffleRank: [String: Int]?

    private struct Line: Identifiable {
        let n: Int
        let entry: Entry
        var id: String { entry.id }
    }

    private var deck: Deck? { store.decks.first { $0.id == deckID } }

    private var lines: [Line] {
        guard let deck else { return [] }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        var out: [Line] = []
        for (i, e) in deck.entries.enumerated() {
            switch filter {
            case .all: break
            case .marked: if e.marker == nil { continue }
            case .color(let c): if e.marker != c { continue }
            }
            if !q.isEmpty && !e.w.lowercased().contains(q) && !e.m.lowercased().contains(q) { continue }
            out.append(Line(n: i + 1, entry: e))
        }
        if let rank = shuffleRank {
            // 섞은 순서로 놓고 번호도 1부터 다시 매겨요
            out = out.sorted { (rank[$0.id] ?? Int.max) < (rank[$1.id] ?? Int.max) }
                .enumerated()
                .map { Line(n: $0.offset + 1, entry: $0.element.entry) }
        }
        return out
    }

    private func shuffle() {
        guard let deck else { return }
        var rank: [String: Int] = [:]
        for (i, e) in deck.entries.shuffled().enumerated() { rank[e.id] = i }
        shuffleRank = rank
    }

    private var hiding: Bool { hideWord || hideMeaning }

    var body: some View {
        GeometryReader { geo in
            let wordWidth = max(180, (geo.size.width - 100) * 0.38)
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        let shown = lines
                        if shown.isEmpty {
                            Text(filter == .all && search.isEmpty ? "단어가 없어요" : "해당하는 단어가 없어요")
                                .foregroundStyle(.secondary)
                                .padding(.top, 60)
                        }
                        ForEach(shown) { line in
                            row(line, wordWidth: wordWidth)
                            Divider().padding(.leading, 16)
                        }
                    } header: {
                        header(wordWidth: wordWidth)
                    }
                }
                .padding(.bottom, markerMode ? 120 : 30)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { controls }
        .overlay(alignment: .bottom) {
            if markerMode { palette }
        }
        .navigationTitle(deck?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "단어·뜻 검색")
        .onChange(of: hideWord) { revealed = [] }
        .onChange(of: hideMeaning) { revealed = [] }
        .confirmationDialog("이 단어장의 형광펜을 모두 지울까요?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("모두 지우기", role: .destructive) { store.clearMarkers(deck: deckID) }
        }
    }

    // MARK: - 위쪽 버튼 줄

    private var controls: some View {
        HStack(spacing: 10) {
            pill("단어 가리기", icon: hideWord ? "eye.slash.fill" : "eye.slash", on: hideWord) { hideWord.toggle() }
            pill("뜻 가리기", icon: hideMeaning ? "eye.slash.fill" : "eye.slash", on: hideMeaning) { hideMeaning.toggle() }
            pill("형광펜", icon: "highlighter", on: markerMode) { markerMode.toggle() }
            pill("섞기", icon: "shuffle", on: shuffleRank != nil) {
                if shuffleRank == nil { shuffle() } else { shuffleRank = nil }
            }
            if shuffleRank != nil {
                Button {
                    shuffle()
                } label: {
                    Label("다시 섞기", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                }
            }

            if hiding && !revealed.isEmpty {
                Button {
                    revealed = []
                } label: {
                    Label("다시 가리기", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(.leading, 4)
            }

            Spacer(minLength: 8)

            Menu {
                Picker("보기", selection: $filter) {
                    Text("전체").tag(DeckFilter.all)
                    Text("형광펜 칠한 것만").tag(DeckFilter.marked)
                    ForEach(Marker.allCases) { c in
                        Text("\(c.name)만").tag(DeckFilter.color(c))
                    }
                }
            } label: {
                Label(filterLabel, systemImage: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 15, weight: .semibold))
            }

            Menu {
                Button { fontSize = min(fontSize + 2, 44) } label: { Label("글자 크게", systemImage: "textformat.size.larger") }
                Button { fontSize = max(fontSize - 2, 14) } label: { Label("글자 작게", systemImage: "textformat.size.smaller") }
                Divider()
                Button(role: .destructive) { confirmClear = true } label: { Label("형광펜 모두 지우기", systemImage: "eraser") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var filterLabel: String {
        switch filter {
        case .all: return "전체"
        case .marked: return "형광펜만"
        case .color(let c): return "\(c.name)만"
        }
    }

    private func pill(_ title: String, icon: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(on ? Color.white : Color.primary)
                .background(on ? Color.accentColor : Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 열 제목 (탭하면 그 열 가리기)

    private func header(wordWidth: CGFloat) -> some View {
        HStack(spacing: 16) {
            Color.clear.frame(width: 36, height: 1)
            headerTitle("단어", hidden: hideWord) { hideWord.toggle() }
                .frame(width: wordWidth, alignment: .leading)
            headerTitle("뜻", hidden: hideMeaning) { hideMeaning.toggle() }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func headerTitle(_ title: String, hidden: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: hidden ? "eye.slash.fill" : "eye")
                    .font(.caption)
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 단어 한 줄

    private func row(_ line: Line, wordWidth: CGFloat) -> some View {
        let e = line.entry
        let open = revealed.contains(e.id)
        let wordHidden = hideWord && !open
        let meaningHidden = hideMeaning && !open
        // 단어나 뜻을 가리면 품사·예문 같은 나머지 정보도 숨겨요 (탭해서 펼치면 다 보여요)
        let showExtras = !hiding || open

        return HStack(alignment: .top, spacing: 16) {
            Text("\(line.n)")
                .font(.system(size: max(12, fontSize * 0.55), weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)
                .padding(.top, fontSize * 0.2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(e.w)
                        .font(.system(size: fontSize, weight: .bold))
                        .highlighted(e.marker)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .covered(wordHidden)
                    // 단어를 가려도 소리는 들을 수 있어요 (듣고 맞히기)
                    Button {
                        if let deck { Speech.shared.say(e.w, deck: deck) }
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: max(16, fontSize * 0.7)))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("단어 읽기")
                }
                if showExtras {
                    if !e.wordTags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(e.wordTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: max(11, fontSize * 0.52), weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .foregroundStyle(Color.accentColor)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    if !e.pron.isEmpty {
                        Text(e.pron)
                            .font(.system(size: max(12, fontSize * 0.6)))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: wordWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(e.m.isEmpty ? " " : e.m)
                    .font(.system(size: fontSize * 0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .covered(meaningHidden)
                if showExtras {
                    ForEach(e.meaningDetails) { d in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(d.label)
                                .font(.system(size: max(11, fontSize * 0.5), weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: max(40, fontSize * 2.2), alignment: .leading)
                            Text(d.value)
                                .font(.system(size: max(12, fontSize * 0.62)))
                                .italic(d.label == "예문")
                                .foregroundStyle(d.label == "예문" ? Color.primary : Color.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(e.marker?.color.opacity(0.12) ?? Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { tap(e) }
        .contextMenu {
            ForEach(Marker.allCases) { c in
                Button {
                    store.setMarker(c, entry: e.id, deck: deckID)
                } label: {
                    Label("\(c.name) 형광펜", systemImage: e.marker == c ? "checkmark.circle.fill" : "circle.fill")
                }
            }
            if e.marker != nil {
                Button(role: .destructive) {
                    store.setMarker(nil, entry: e.id, deck: deckID)
                } label: {
                    Label("형광펜 지우기", systemImage: "eraser")
                }
            }
        }
    }

    private func tap(_ e: Entry) {
        if markerMode {
            // 같은 색을 다시 칠하면 지워져요
            store.setMarker(e.marker == pen ? nil : pen, entry: e.id, deck: deckID)
            return
        }
        guard hiding else { return }
        if revealed.contains(e.id) {
            revealed.remove(e.id)
        } else {
            revealed.insert(e.id)
        }
    }

    // MARK: - 형광펜 색 고르기

    private var palette: some View {
        HStack(spacing: 14) {
            ForEach(Marker.allCases) { c in
                Button {
                    pen = c
                } label: {
                    Circle()
                        .fill(c.color)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(Color.primary, lineWidth: pen == c ? 3 : 0))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(c.name) 형광펜")
            }
            Divider().frame(height: 32)
            Button {
                pen = nil
            } label: {
                Image(systemName: "eraser")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(pen == nil ? Color.accentColor.opacity(0.2) : Color.clear, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("지우개")
            Text(pen == nil ? "단어를 탭하면 지워져요" : "단어를 탭해서 칠하기")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.bottom, 24)
    }
}

private extension View {
    /// 가리기: 자리는 그대로 두고 회색 덮개로 덮어요
    func covered(_ on: Bool) -> some View {
        opacity(on ? 0 : 1)
            .overlay {
                if on {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "eye.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        )
                }
            }
    }

    /// 형광펜: 글자 뒤에 색을 칠해요
    func highlighted(_ marker: Marker?) -> some View {
        padding(.horizontal, marker == nil ? 0 : 4)
            .background {
                if let marker {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(marker.color.opacity(0.7))
                        .padding(.top, 6)
                }
            }
    }
}
