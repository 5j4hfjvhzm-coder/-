import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var provider = AIClient.preferredProvider
    @State private var claudeKey = Keychain.get(.claude) ?? ""
    @State private var geminiKey = Keychain.get(.gemini) ?? ""
    @State private var saved = false
    @State private var testResult: String?
    @State private var testing = false
    @State private var fontStatus = ""

    var body: some View {
        TabView {
            aeTab.tabItem { Label("After Effects", systemImage: "film") }
            aiTab.tabItem { Label("AI", systemImage: "sparkles") }
            fontTab.tabItem { Label("폰트", systemImage: "textformat") }
        }
        .frame(width: 560, height: 430)
    }

    private var aeTab: some View {
        Form {
            Section("사용할 After Effects") {
                if model.aeApps.isEmpty {
                    Text("/Applications 에서 After Effects를 찾지 못했어요.").foregroundStyle(.orange)
                } else {
                    Picker("버전", selection: Binding(get: { model.selectedAE?.url.path ?? "" }, set: { model.selectedAEPath = $0 })) {
                        ForEach(model.aeApps) { Text($0.name).tag($0.url.path) }
                    }
                }
                Button("다시 찾기") { model.aeApps = AERunner.installed() }
            }
            Section("처음 한 번만 해 주세요") {
                Text("1. After Effects › 설정(Settings) › 스크립팅 및 표현식(Scripting & Expressions) › **스크립트가 파일을 쓰고 네트워크에 액세스하도록 허용** 켜기")
                Text("2. 처음 만들 때 \"에딧 메이커가 After Effects를 제어하려고 합니다\" 창이 뜨면 **허용**")
                Text("3. 폰트를 새로 받은 직후라면 After Effects를 한 번 껐다 켜기")
            }
            .font(.system(size: 12))
        }
        .formStyle(.grouped)
    }

    private var aiTab: some View {
        Form {
            Section {
                Picker("AI", selection: $provider) {
                    ForEach(AIProvider.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                SecureField("Claude API 키 (sk-ant-...)", text: $claudeKey)
                SecureField("Gemini API 키", text: $geminiKey)
                HStack {
                    Button("저장") {
                        AIClient.preferredProvider = provider
                        Keychain.set(.claude, claudeKey)
                        Keychain.set(.gemini, geminiKey)
                        saved = true
                        model.objectWillChange.send()
                    }
                    Button(testing ? "확인 중…" : "연결 테스트") { test() }.disabled(testing)
                    if saved { Text("저장됨").foregroundStyle(.green).font(.system(size: 11)) }
                }
                if let testResult { Text(testResult).font(.system(size: 11.5)) }
            } header: {
                Text("AI 감독 (선택)")
            } footer: {
                Text("AI가 레퍼런스 장면을 보고 자막 스타일을 고르고, 영상 검토 후 \"자막 더 크게\" 같은 수정 요청을 처리해요. 키는 이 Mac의 키체인에만 저장돼요. 사용량만큼 각 회사에 요금이 나가요. 키가 없어도 규칙 기반으로 만들 수 있고, 타임라인에서 직접 고칠 수 있어요.")
                    .font(.system(size: 11))
            }
        }
        .formStyle(.grouped)
    }

    private var fontTab: some View {
        Form {
            Section("자막 폰트 (Google Fonts 무료 · OFL)") {
                ForEach(Catalog.fonts) { f in
                    HStack {
                        Text(f.name).font(.custom(f.id, size: 16))
                        Text(f.id).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: FontInstaller.isInstalled(f) ? "checkmark.circle.fill" : "arrow.down.circle")
                            .foregroundStyle(FontInstaller.isInstalled(f) ? Color.green : Color.secondary)
                    }
                }
                HStack {
                    Button("지금 받기") {
                        Task {
                            do {
                                let n = try await FontInstaller.installMissing { s in Task { @MainActor in fontStatus = s } }
                                fontStatus = n == 0 ? "모두 설치돼 있어요" : "\(n)개 설치 완료 · After Effects를 다시 켜 주세요"
                            } catch {
                                fontStatus = error.localizedDescription
                            }
                        }
                    }
                    Text(fontStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func test() {
        AIClient.preferredProvider = provider
        Keychain.set(.claude, claudeKey)
        Keychain.set(.gemini, geminiKey)
        guard let c = AIClient.current() else { testResult = AIError.noKey.localizedDescription; return }
        testing = true
        testResult = nil
        Task {
            do {
                let r = try await c.complete(system: "짧게 답해.", text: "연결 테스트야. '연결 성공'이라고만 답해.")
                testResult = "✅ \(c.provider.name): \(r.prefix(40))"
            } catch {
                testResult = "❌ " + ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
            testing = false
        }
    }
}
