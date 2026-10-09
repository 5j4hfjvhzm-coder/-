import SwiftUI

/// AI 영어 프리토킹: 영어로 대화하고, 틀린 문장은 한국어로 교정해 줘요.
struct ChatView: View {
    let bookIDs: [Int]
    @Environment(Store.self) private var store
    @State private var msgs: [ChatMessage] = []
    @State private var targetWords: [String] = []
    @State private var input = ""
    @State private var busy = false
    @State private var failed: Set<UUID> = []
    @FocusState private var focused: Bool

    private let greeting = "Hi! Let's chat. What did you do today?"

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI 프리토킹").font(.system(size: 28, weight: .heavy))
                        Text("영어로 자유롭게 말해 보세요. 틀린 문장은 고쳐 주고 이유를 설명해 줘요."
                             + (targetWords.isEmpty ? "" : "\n오늘의 단어: " + targetWords.joined(separator: ", ")))
                            .font(.subheadline).foregroundStyle(Theme.sub)
                            .padding(.bottom, 8)
                        Bubble(text: greeting, kind: .ai)
                        ForEach(Array(msgs.enumerated()), id: \.element.id) { idx, m in
                            if m.role == .user {
                                Bubble(text: m.text, kind: .me)
                            } else {
                                let p = m.parts
                                let streaming = busy && idx == msgs.count - 1
                                Bubble(text: p.reply.isEmpty ? "…" : p.reply, kind: .ai, speakable: !streaming && !p.reply.isEmpty)
                                if let f = p.feedback { Bubble(text: f, kind: .feedback) }
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: msgs) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            HStack(spacing: 8) {
                TextField("영어로 입력…", text: $input)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .focused($focused)
                    .onSubmit(send)
                    .disabled(busy)
                    .field()
                Button("보내기", action: send)
                    .buttonStyle(.pillPrimary)
                    .disabled(busy || input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.bg)
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard targetWords.isEmpty else { return }
            // ★ 헷갈리는 단어를 우선해서 최대 12개를 대화 목표 단어로 골라요.
            let ws = store.words(in: bookIDs).shuffled()
            targetWords = (ws.filter(\.star) + ws.filter { !$0.star }).prefix(12).map(\.w)
            focused = true
        }
    }

    private var systemPrompt: String {
        """
        You are a friendly English conversation partner for a Korean middle-school learner (TOEFL Junior level). Rules:
        1) Reply in simple English, 1-3 sentences, and end with a follow-up question. \(targetWords.isEmpty ? "" : "Naturally use some of these target words when possible: " + targetWords.joined(separator: ", ") + ".")
        2) Then write a line containing only --- and below it Korean feedback on the learner's LATEST message: if there are grammar, word-choice or spelling mistakes, write "✏️ 교정: <corrected sentence>" and "💡 이유: <short Korean explanation>". If it is correct, write "👍 완벽해요!" and one more natural alternative expression. Never skip the --- line.
        The conversation opened with you saying: "\(greeting)"
        """
    }

    private func send() {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !busy else { return }
        guard let client = ClaudeClient.fromSettings() else {
            store.show("AI 기능을 쓰려면 설정에서 Claude API 키를 입력하세요.")
            return
        }
        input = ""
        // 실패한 답변(오류 메시지)은 빼고, 사용자 메시지 바로 뒤에 온 AI 답변만 대화 기록으로 보내요.
        var history: [ClaudeClient.Message] = []
        for m in msgs where !m.text.isEmpty && !(m.role == .assistant && failed.contains(m.id)) {
            if m.role == .assistant && history.last?.role != .user { continue }
            if m.role == .user && history.last?.role == .user { history.removeLast() }
            history.append(.init(role: m.role, text: m.text))
        }
        if history.last?.role == .user { history.removeLast() }
        history.append(.init(role: .user, text: t))
        msgs.append(ChatMessage(role: .user, text: t))
        msgs.append(ChatMessage(role: .assistant, text: ""))
        let idx = msgs.count - 1
        busy = true
        Task {
            do {
                let final = try await client.stream(system: systemPrompt, messages: history) { partial in
                    if idx < msgs.count { msgs[idx].text = partial }
                }
                if idx < msgs.count { msgs[idx].text = final }
            } catch {
                if idx < msgs.count {
                    failed.insert(msgs[idx].id)
                    msgs[idx].text = (error as? LocalizedError)?.errorDescription ?? "AI 응답에 실패했어요. 잠시 후 다시 시도하세요."
                }
            }
            busy = false
            focused = true
        }
    }
}

private struct Bubble: View {
    enum Kind { case me, ai, feedback }
    let text: String
    let kind: Kind
    var speakable = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Text(text)
                .textSelection(.enabled)
            if speakable {
                Button { Speech.shared.say(text) } label: { Image(systemName: "speaker.wave.2") }
                    .foregroundStyle(Theme.sub)
                    .buttonStyle(.borderless)
                    .accessibilityLabel("읽기")
            }
        }
        .font(kind == .feedback ? .subheadline : .body)
        .foregroundStyle(fg)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, alignment: kind == .me ? .trailing : .leading)
        .padding(.leading, kind == .me ? 40 : 0)
        .padding(.trailing, kind == .ai ? 24 : 0)
    }

    private var fg: Color {
        switch kind {
        case .me: return .white
        case .ai: return Theme.ink
        case .feedback: return Theme.hintInk
        }
    }

    private var bg: Color {
        switch kind {
        case .me: return Theme.pri
        case .ai: return Theme.card
        case .feedback: return Theme.hint
        }
    }
}
