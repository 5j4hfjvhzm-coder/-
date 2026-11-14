import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var clearTarget: ClearTarget?

    private struct ClearTarget: Identifiable {
        let platform: Platform?
        var id: String { platform?.rawValue ?? "all" }
        var title: String {
            platform.map { "\($0.name)에서 로그아웃할까요?" } ?? "모든 사이트 데이터를 지울까요?"
        }
    }

    var body: some View {
        @Bindable var s = model.settings
        Form {
            Section {
                ForEach(Platform.allCases) { p in
                    Toggle(isOn: Binding(
                        get: { s.isEnabled(p) },
                        set: { s.setEnabled(p, $0); model.validateSelection() }
                    )) {
                        Label(p.name, systemImage: p.symbol)
                    }
                    .disabled(s.isEnabled(p) && s.enabledPlatforms.count == 1)
                }
                Picker("처음 열 탭", selection: $s.startTab) {
                    ForEach(s.enabledPlatforms) { Text($0.name).tag($0) }
                }
                Toggle("탭을 바꾸면 영상 멈추기", isOn: $s.pauseOnSwitch)
            } header: {
                Text("탭")
            }

            Section {
                ForEach(s.enabledPlatforms) { p in
                    Picker(p.name, selection: Binding(
                        get: { s.startPage(p) },
                        set: { s.setStartPage($0, for: p) }
                    )) {
                        ForEach(StartPage.allCases, id: \.self) { Text(p.label(for: $0)).tag($0) }
                    }
                }
            } header: {
                Text("시작 화면")
            } footer: {
                Text("아래 탭을 한 번 더 누르면 맨 위로, 맨 위에서 또 누르면 시작 화면으로 가요.")
            }

            Section {
                Toggle("쇼츠 숨기기", isOn: $s.hideShorts)
                Toggle("쇼츠를 일반 영상으로 열기", isOn: $s.shortsAsVideo)
            } header: {
                Label("YouTube", systemImage: Platform.youtube.symbol)
            } footer: {
                Text("일반 영상으로 열면 세로 스와이프 없이 한 편씩 봐요.")
            }

            Section {
                Toggle("릴스 탭 숨기기", isOn: $s.hideReelsTab)
                Toggle("릴스 피드 막기", isOn: $s.blockReelsFeed)
                Toggle("광고 게시물 숨기기", isOn: $s.hideSponsored)
            } header: {
                Label("Instagram", systemImage: Platform.instagram.symbol)
            } footer: {
                Text("릴스 피드를 막아도 공유받은 릴스 링크 하나는 열려요.")
            }

            Section {
                Toggle("광고 배너 숨기기", isOn: $s.hideAds)
                Toggle("'앱에서 열기' 안내 숨기기", isOn: $s.hideAppBanners)
                Toggle("흑백 화면", isOn: $s.grayscale)
            } header: {
                Text("공통")
            } footer: {
                Text("각 사이트의 화면 구조가 바뀌면 일부가 숨겨지지 않을 수 있어요. 동영상 재생 중 광고는 건드리지 않아요.")
            }

            Section {
                ForEach(s.enabledPlatforms) { p in
                    let limit = s.limit(for: p)
                    Stepper(value: Binding(get: { s.limit(for: p) }, set: { s.setLimit($0, for: p) }),
                            in: 0...240, step: 5) {
                        HStack {
                            Text(p.name)
                            Spacer()
                            Text(limit == 0 ? "제한 없음" : "\(limit)분")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("하루 사용 시간 제한")
            } footer: {
                Text("시간이 다 되면 영상이 멈추고 화면이 가려져요. '5분만 더'를 누를 수 있어요. 날짜가 바뀌면 다시 시작해요.")
            }

            Section {
                ForEach(Platform.allCases) { p in
                    Button("\(p.name) 로그아웃", role: .destructive) {
                        clearTarget = ClearTarget(platform: p)
                    }
                }
                Button("모든 사이트 데이터 지우기", role: .destructive) {
                    clearTarget = ClearTarget(platform: nil)
                }
            } header: {
                Text("로그인·데이터")
            } footer: {
                Text("로그인은 이 앱 안에만 저장돼요. 로그아웃하면 그 사이트의 쿠키와 저장 데이터가 지워져요.")
            }

            Section("정보") {
                LabeledContent("버전", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                Text("SocialLite는 YouTube·TikTok·Instagram의 공식 모바일 웹사이트를 앱 안에서 여는 가벼운 브라우저예요. 각 서비스와 관련 없는 개인용 앱이에요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            clearTarget?.title ?? "",
            isPresented: Binding(get: { clearTarget != nil }, set: { if !$0 { clearTarget = nil } }),
            titleVisibility: .visible,
            presenting: clearTarget
        ) { target in
            Button(target.platform == nil ? "모두 지우기" : "로그아웃", role: .destructive) {
                Task { await model.clearData(for: target.platform) }
            }
            Button("취소", role: .cancel) {}
        }
    }
}
