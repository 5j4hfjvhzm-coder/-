import SwiftUI

struct MoreView: View {
    @Environment(AppModel.self) private var model
    @State private var linkText = ""
    @FocusState private var linkFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("youtu.be/… · tiktok.com/… · instagram.com/…", text: $linkText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($linkFocused)
                        .onSubmit(openTyped)
                    HStack {
                        PasteButton(payloadType: String.self) { strings in
                            let text = strings.first ?? ""
                            Task { @MainActor in
                                linkText = text
                                openTyped()
                            }
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonBorderShape(.capsule)
                        Spacer()
                        Button("열기", action: openTyped)
                            .buttonStyle(.borderedProminent)
                            .disabled(linkText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("링크 열기")
                } footer: {
                    Text("받은 링크를 붙여 넣으면 맞는 탭에서 열려요. 그 밖의 링크는 Safari 창으로 열려요.")
                }

                Section("오늘 사용 시간") {
                    ForEach(model.visiblePlatforms) { p in
                        UsageRow(platform: p)
                    }
                    NavigationLink {
                        UsageView()
                    } label: {
                        Label("최근 7일 보기", systemImage: "chart.bar")
                    }
                }

                Section {
                    NavigationLink {
                        SavedView()
                    } label: {
                        HStack {
                            Label("저장한 링크", systemImage: "bookmark")
                            Spacer()
                            Text("\(model.bookmarks.items.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("설정", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("SocialLite")
        }
    }

    private func openTyped() {
        if model.openText(linkText) {
            linkText = ""
            linkFocused = false
        } else if !linkText.isEmpty {
            model.showToast("링크를 찾지 못했어요")
        }
    }
}

struct UsageRow: View {
    @Environment(AppModel.self) private var model
    let platform: Platform

    var body: some View {
        let used = model.usage.seconds(platform)
        let limit = model.settings.limit(for: platform)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: platform.symbol)
                    .foregroundStyle(platform.tint)
                    .frame(width: 26)
                Text(platform.name)
                Spacer()
                Text(limit > 0 ? "\(formatDuration(used)) / \(limit)분" : formatDuration(used))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if limit > 0 {
                ProgressView(value: min(used / Double(limit * 60), 1))
                    .tint(model.isOverLimit(platform) ? .orange : platform.tint)
            }
        }
    }
}
