import SwiftUI

struct SettingsView: View {
    @State private var key = Keychain.apiKey ?? ""
    @State private var saved = Keychain.apiKey?.isEmpty == false
    @Environment(Store.self) private var store

    var body: some View {
        Form {
            Section {
                SecureField("sk-ant-...", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    Button("저장") {
                        Keychain.apiKey = key
                        saved = !(Keychain.apiKey ?? "").isEmpty
                        store.show(saved ? "API 키를 저장했어요." : "API 키를 지웠어요.")
                    }
                    Spacer()
                    if saved {
                        Button("지우기", role: .destructive) {
                            key = ""
                            Keychain.apiKey = nil
                            saved = false
                            store.show("API 키를 지웠어요.")
                        }
                    }
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Claude API 키")
            } footer: {
                Text("\"AI로 틀린 이유 설명\"과 \"AI 프리토킹\"에 쓰여요. console.anthropic.com에서 발급받을 수 있고, 키는 이 기기의 키체인에만 저장돼요. 사용한 만큼 Anthropic 계정에 요금이 청구돼요.")
            }

            Section("정보") {
                LabeledContent("AI 모델", value: ClaudeClient.model)
                LabeledContent("저장 위치", value: "이 기기 (앱 문서 폴더)")
            }
        }
        .navigationTitle("설정")
    }
}
