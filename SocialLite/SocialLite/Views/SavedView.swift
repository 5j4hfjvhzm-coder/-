import SwiftUI

struct SavedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.bookmarks.items.isEmpty {
                ContentUnavailableView(
                    "저장한 링크가 없어요",
                    systemImage: "bookmark",
                    description: Text("영상이나 게시물을 보다가 오른쪽 위 ⋯ › 링크 저장을 누르세요.")
                )
            } else {
                List {
                    ForEach(model.bookmarks.items) { item in
                        Button {
                            model.openLink(item.url)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.platform?.symbol ?? "link")
                                    .foregroundStyle(item.platform?.tint ?? .secondary)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text(item.url.host ?? item.url.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .contextMenu {
                            ShareLink(item: item.url) { Label("공유", systemImage: "square.and.arrow.up") }
                            Button {
                                UIPasteboard.general.string = item.url.absoluteString
                                model.showToast("링크를 복사했어요")
                            } label: { Label("링크 복사", systemImage: "doc.on.doc") }
                        }
                    }
                    .onDelete { offsets in
                        let ids = Set(offsets.map { model.bookmarks.items[$0].id })
                        model.bookmarks.remove(ids)
                    }
                }
            }
        }
        .navigationTitle("저장한 링크")
        .navigationBarTitleDisplayMode(.inline)
    }
}
