import SwiftUI

/// 플래시카드: 카드를 탭해서 뒤집고, 오른쪽으로 밀면 "알아요", 왼쪽으로 밀면 "몰라요".
struct FlashcardView: View {
    let bookIDs: [Int]
    @Environment(Store.self) private var store
    @AppStorage("flashFrontIsWord") private var frontIsWord = true
    @AppStorage("flashShuffle") private var shuffle = true
    @AppStorage("flashAutoSpeak") private var autoSpeak = false
    @State private var starOnly = false
    @State private var deck: [Word] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var known = 0
    @State private var unknown: [Word] = []
    @State private var offset: CGSize = .zero
    @State private var started = false
    @State private var moving = false

    private var current: Word? { index < deck.count ? deck[index] : nil }

    var body: some View {
        VStack(spacing: 14) {
            if deck.isEmpty {
                Spacer()
                Text(starOnly ? "★ 표시한 단어가 없어요." : "단어가 없어요.")
                    .foregroundStyle(Theme.sub)
                Spacer()
            } else if let w = current {
                progress
                card(w)
                    .offset(x: offset.width, y: offset.height * 0.2)
                    .rotationEffect(.degrees(Double(offset.width) / 20))
                    .gesture(drag)
                    .onTapGesture { flip() }
                swipeHint
                controls(w)
            } else {
                summary
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .navigationTitle("플래시카드")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("앞면", selection: $frontIsWord) {
                        Text("앞면: 영어 단어").tag(true)
                        Text("앞면: 뜻").tag(false)
                    }
                    Toggle("섞기", isOn: $shuffle)
                    Toggle("★ 헷갈리는 단어만", isOn: $starOnly)
                    Toggle("카드 넘길 때 단어 읽기", isOn: $autoSpeak)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("플래시카드 설정")
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            restart()
        }
        .onChange(of: shuffle) { restart() }
        .onChange(of: starOnly) { restart() }
        .onChange(of: frontIsWord) { flipped = false }
    }

    // MARK: - 화면 조각

    private var progress: some View {
        HStack(spacing: 10) {
            ProgressView(value: Double(index), total: Double(max(deck.count, 1)))
                .tint(Theme.pri)
            Text("\(index + 1)/\(deck.count)").font(.footnote).monospacedDigit()
        }
    }

    private func card(_ w: Word) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            Group {
                if flipped {
                    back(w).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                } else {
                    front(w)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        // 밀 때 나오는 "알아요/몰라요" 도장 (뒤집혀도 글자가 거꾸로 보이지 않게 회전 바깥에 둬요)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(stampColor.opacity(stampOpacity), lineWidth: 4)
        }
        .overlay(alignment: offset.width > 0 ? .topLeading : .topTrailing) {
            if stampOpacity > 0 {
                Text(offset.width > 0 ? "알아요" : "몰라요")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(stampColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(stampColor, lineWidth: 3))
                    .rotationEffect(.degrees(offset.width > 0 ? -12 : 12))
                    .opacity(stampOpacity)
                    .padding(20)
            }
        }
        .contentShape(Rectangle())
    }

    private func front(_ w: Word) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            if frontIsWord {
                Text(w.w)
                    .font(.system(size: 40, weight: .heavy))
                    .minimumScaleFactor(0.4)
                    .lineLimit(2)
            } else {
                Text(w.m)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Theme.ok)
                    .minimumScaleFactor(0.4)
            }
            Spacer(minLength: 0)
            Text("탭해서 뒤집기")
                .font(.footnote)
                .foregroundStyle(Theme.sub)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func back(_ w: Word) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(w.w).font(.system(size: 30, weight: .heavy))
                Text(w.m).font(.title3.weight(.heavy)).foregroundStyle(Theme.ok)
                if !w.e.isEmpty {
                    exampleText(w)
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.soft, in: RoundedRectangle(cornerRadius: 14))
                }
                WordDetailCard(word: w, showHeader: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    /// 예문에서 단어 부분을 굵게
    private func exampleText(_ w: Word) -> Text {
        let b = Blank(w)
        guard !b.pre.isEmpty || !b.post.isEmpty else { return Text(w.e) }
        return Text(b.pre) + Text(b.ans).bold().foregroundColor(Theme.pri) + Text(b.post)
    }

    private var swipeHint: some View {
        HStack {
            Label("몰라요", systemImage: "arrow.left")
            Spacer()
            Label("알아요", systemImage: "arrow.right")
                .labelStyle(TrailingIconLabelStyle())
        }
        .font(.caption)
        .foregroundStyle(Theme.sub)
    }

    private func controls(_ w: Word) -> some View {
        let starred = store.words(in: bookIDs).first { $0.id == w.id }?.star ?? w.star
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { answer(knew: false) } label: {
                    Text("몰라요").frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(primary: false))
                Button { answer(knew: true) } label: {
                    Text("알아요").frame(maxWidth: .infinity)
                }
                .buttonStyle(.pillPrimary)
            }
            HStack(spacing: 10) {
                Button { goBack() } label: { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(.pill)
                    .disabled(index == 0)
                    .accessibilityLabel("이전 카드")
                Button { flip() } label: { Label("뒤집기", systemImage: "arrow.left.arrow.right") }
                    .buttonStyle(.pill)
                Button { Speech.shared.say(w.e.isEmpty ? w.w : w.w + ". " + w.e) } label: { Image(systemName: "speaker.wave.2.fill") }
                    .buttonStyle(.pill)
                    .accessibilityLabel("읽기")
                Button { store.toggleStar(wordID: w.id) } label: {
                    Image(systemName: starred ? "star.fill" : "star")
                        .foregroundStyle(starred ? Theme.starOn : Theme.pri)
                }
                .buttonStyle(.pill)
                .accessibilityLabel("헷갈리는 단어 표시")
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("다 봤어요!")
                .font(.system(size: 28, weight: .heavy))
                .padding(.top, 20)
            Text("알아요 \(known)개 · 몰라요 \(unknown.count)개")
                .foregroundStyle(Theme.sub)
            if !unknown.isEmpty {
                SectionTitle("몰랐던 단어")
                VStack(spacing: 0) {
                    ForEach(unknown) { w in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(w.w).font(.headline).frame(minWidth: 96, alignment: .leading)
                            Text(w.m)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        if w.id != unknown.last?.id { Divider().overlay(Theme.line) }
                    }
                }
                .card()
            }
            FlowLayout {
                if !unknown.isEmpty {
                    Button("몰랐던 카드만 다시 (\(unknown.count))") { retryUnknown() }
                        .buttonStyle(.pillPrimary)
                    Button("몰랐던 단어 ★ 표시") { starUnknown() }
                        .buttonStyle(.pill)
                }
                Button("처음부터 다시") { restart() }
                    .buttonStyle(.pill)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 동작

    private var stampColor: Color { offset.width > 0 ? Theme.ok : Theme.bad }
    private var stampOpacity: Double { min(abs(Double(offset.width)) / 100, 1) }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { offset = $0.translation }
            .onEnded { v in
                if abs(v.translation.width) > 110 {
                    answer(knew: v.translation.width > 0)
                } else {
                    withAnimation(.spring(response: 0.3)) { offset = .zero }
                }
            }
    }

    private func flip() {
        withAnimation(.easeInOut(duration: 0.3)) { flipped.toggle() }
    }

    private func answer(knew: Bool) {
        guard !moving, let w = current else { return }
        moving = true
        if knew {
            known += 1
        } else if !unknown.contains(where: { $0.id == w.id }) {
            unknown.append(w)
        }
        withAnimation(.easeIn(duration: 0.2)) {
            offset = CGSize(width: knew ? 600 : -600, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            offset = .zero
            flipped = false
            index += 1
            moving = false
            speakIfNeeded()
        }
    }

    private func goBack() {
        guard !moving, index > 0 else { return }
        index -= 1
        flipped = false
        if let w = current {
            unknown.removeAll { $0.id == w.id }
        }
    }

    private func load(_ words: [Word]) {
        deck = shuffle ? words.shuffled() : words
        index = 0
        known = 0
        unknown = []
        flipped = false
        offset = .zero
        moving = false
        speakIfNeeded()
    }

    private func restart() {
        let all = store.words(in: bookIDs)
        load(starOnly ? all.filter(\.star) : all)
    }

    private func retryUnknown() {
        load(unknown)
    }

    private func starUnknown() {
        let starredIDs = Set(store.words(in: bookIDs).filter(\.star).map(\.id))
        for w in unknown where !starredIDs.contains(w.id) {
            store.toggleStar(wordID: w.id)
        }
        store.show("몰랐던 단어 \(unknown.count)개를 ★ 표시했어요.")
    }

    private func speakIfNeeded() {
        guard autoSpeak, let w = current else { return }
        Speech.shared.say(w.w)
    }
}

/// 아이콘을 글자 오른쪽에 두는 라벨
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}
