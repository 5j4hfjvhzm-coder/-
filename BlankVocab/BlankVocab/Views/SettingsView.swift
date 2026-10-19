import SwiftUI
import UIKit

struct SettingsView: View {
    @State private var key = Keychain.apiKey ?? ""
    @State private var saved = Keychain.apiKey?.isEmpty == false
    @State private var keyboardTest = ""
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
                LabeledContent("AI 모델", value: ClaudeClient.model)
                LabeledContent("저장 위치", value: "이 기기 (앱 문서 폴더)")
            }
        }
        .navigationTitle("설정")
    }
}
