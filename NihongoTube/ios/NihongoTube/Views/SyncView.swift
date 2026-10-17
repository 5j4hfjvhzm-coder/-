import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 아이폰·맥 단어장 동기화 설정
struct SyncView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false

    var body: some View {
        let sync = app.sync
        NavigationStack {
            List {
                Section {
                    if let name = sync.folderName {
                        LabeledContent("동기화 폴더", value: name)
                        LabeledContent("마지막 동기화") {
                            if sync.syncing {
                                ProgressView().controlSize(.small)
                            } else if let t = sync.lastSync {
                                Text(t.formatted(date: .omitted, time: .standard))
                            } else {
                                Text("아직 안 함").foregroundStyle(.secondary)
                            }
                        }
                        if let e = sync.error {
                            Text(e).font(.footnote).foregroundStyle(.red)
                        }
                        Button("지금 동기화") { sync.syncNow() }
                            .disabled(sync.syncing)
                        Button("다른 폴더 고르기") { picking = true }
                        Button("동기화 끊기", role: .destructive) { sync.disconnect() }
                    } else {
                        Button {
                            picking = true
                        } label: {
                            Label("동기화 폴더 고르기", systemImage: "folder.badge.plus")
                        }
                    }
                } footer: {
                    Text("이 기기의 단어 \(app.vocab.words.count)개")
                }

                Section("설정 방법") {
                    step(1, "iCloud Drive 에 폴더를 하나 만들어요. 예: \"유튜브 단어장\"")
                    step(2, "아이폰에서 \"동기화 폴더 고르기\" → iCloud Drive → 그 폴더를 열고 \"열기\"")
                    step(3, "맥에서도 같은 폴더를 골라요 (Finder 의 iCloud Drive)")
                    step(4, "그다음부터는 단어를 저장·삭제하거나 ★를 바꾸면 자동으로 맞춰져요. 앱을 열어 둔 동안 30초마다 확인해요.")
                }

                Section {
                    Text("폴더 안에 \(syncFileName) 파일 하나가 생겨요. 두 기기의 단어를 합쳐서 쓰기 때문에 한쪽에만 있던 단어도 사라지지 않고, 지운 단어는 양쪽에서 지워져요. 아이폰과 맥이 같은 Apple ID 로 iCloud Drive 에 로그인되어 있어야 해요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("기기 간 동기화")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    sync.connect(url)
                }
            }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)").font(.subheadline.bold()).foregroundStyle(Color.accentColor)
            Text(text).font(.subheadline)
        }
    }
}
