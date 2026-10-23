import SwiftUI
import UIKit

struct SettingsView: View {
    @State private var provider = AI.provider
    @State private var keyboardTest = ""
    @Environment(Store.self) private var store

    var body: some View {
        Form {
            Section {
                Picker("사용할 AI", selection: $provider) {
                    ForEach(AIProvider.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: provider) { AI.provider = provider }
            } header: {
                Text("AI 선택")
            } footer: {
                Text("\"AI로 틀린 이유 설명\"과 \"AI 프리토킹\"에 여기서 고른 AI를 써요. 키는 이 기기의 키체인에만 저장돼요.")
            }

            APIKeySection(provider: .claude)
            APIKeySection(provider: .gemini)

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. 설정 › 일반 › 키보드 › 키보드 › 새로운 키보드 추가")
                    Text("2. '빈칸 단어장 키보드' 선택")
                    Text("3. 추가된 키보드를 눌러 '전체 접근 허용' 켜기 (사전 검색에 인터넷이 필요해요)")
                    Text("4. 아무 입력창에서 🌐 키로 키보드를 바꾸고, 위쪽 📖 버튼으로 사전 열기")
                }
                .font(.footnote)
                Button("설정 앱 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                TextField("여기서 키보드를 시험해 보세요", text: $keyboardTest)
            } header: {
                Text("사전 키보드")
            } footer: {
                Text("한/영 키로 입력 언어를 바꾸고, 📖 버튼을 누르면 커서 앞 단어를 네이버 사전에서 바로 찾아요. 검색어는 Naver로 전송돼요.")
            }

            Section("정보") {
                LabeledContent("AI 모델", value: provider == .claude ? ClaudeClient.model : AI.geminiModel)
                LabeledContent("저장 위치", value: "이 기기 (앱 문서 폴더)")
            }
        }
        .navigationTitle("설정")
    }
}

/// AI 한 종류의 API 키 입력 칸 (저장 / 연결 테스트 / 지우기)
private struct APIKeySection: View {
    let provider: AIProvider
    @Environment(Store.self) private var store
    @State private var key = ""
    @State private var saved = false
    @State private var model = AI.geminiModel
    @State private var testing = false
    @State private var result: (ok: Bool, text: String)?

    var body: some View {
        Section {
            SecureField(provider == .claude ? "sk-ant-..." : "AQ....", text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if provider == .gemini {
                LabeledContent("모델") {
                    TextField(AI.defaultGeminiModel, text: $model)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { AI.geminiModel = model }
                }
            }
            HStack {
                Button("저장") { save() }
                Spacer()
                if saved {
                    Button(testing ? "확인 중…" : "연결 테스트") { Task { await test() } }
                        .disabled(testing)
                    Spacer()
                    Button("지우기", role: .destructive) {
                        key = ""
                        setKey(nil)
                        saved = false
                        result = nil
                        store.show("\(provider.name) API 키를 지웠어요.")
                    }
                }
            }
            .buttonStyle(.borderless)
            if let result {
                Text(result.text)
                    .font(.footnote)
                    .foregroundStyle(result.ok ? Theme.ok : Theme.bad)
                    .textSelection(.enabled)
            }
        } header: {
            Text("\(provider.name) API 키")
        } footer: {
            Text(footer)
        }
        .onAppear {
            key = AI.key(for: provider) ?? ""
            saved = !key.isEmpty
        }
    }

    private var footer: String {
        switch provider {
        case .claude:
            return "console.anthropic.com에서 발급받아요. sk-ant-로 시작해요. 사용한 만큼 Anthropic 계정에 요금이 청구돼요."
        case .gemini:
            return "aistudio.google.com에서 \"Get API key\"로 발급받아요. 키는 AQ.로 시작해요(예전 키는 AIza). gen-lang-client-...는 프로젝트 이름이라 키가 아니에요. 모델은 비워 두면 \(AI.defaultGeminiModel)(항상 최신 Flash)을 써요."
        }
    }

    private func setKey(_ v: String?) {
        switch provider {
        case .claude: Keychain.apiKey = v
        case .gemini: Keychain.geminiKey = v
        }
    }

    private func save() {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider == .gemini {
            AI.geminiModel = model
            model = AI.geminiModel
        }
        setKey(k)
        key = k
        result = nil
        saved = !k.isEmpty
        guard saved else {
            store.show("\(provider.name) API 키를 지웠어요.")
            return
        }
        if provider == .claude && !k.hasPrefix("sk-ant-") {
            store.show("저장했어요. 그런데 Claude 키는 보통 sk-ant-로 시작해요. 연결 테스트로 확인해 보세요.")
        } else if provider == .gemini && !(k.hasPrefix("AQ.") || k.hasPrefix("AIza")) {
            store.show(k.hasPrefix("gen-lang") ? "gen-lang-client-...는 프로젝트 이름이에요. AI Studio에서 키를 복사해 넣어 주세요."
                                              : "저장했어요. 그런데 Gemini 키는 보통 AQ.로 시작해요. 연결 테스트로 확인해 보세요.")
        } else {
            store.show("\(provider.name) API 키를 저장했어요.")
        }
    }

    private func test() async {
        if provider == .gemini { AI.geminiModel = model }
        guard let client = AI.client(for: provider) else { return }
        testing = true
        result = nil
        defer { testing = false }
        do {
            _ = try await client.stream(messages: [AIMessage(role: .user, text: "Reply with just: OK")]) { _ in }
            if provider == .gemini { model = AI.geminiModel }
            result = (true, "연결됐어요. ✅" + (provider == .gemini ? " (모델: \(AI.geminiModel))" : ""))
        } catch {
            result = (false, AI.describe(error))
        }
    }
}
