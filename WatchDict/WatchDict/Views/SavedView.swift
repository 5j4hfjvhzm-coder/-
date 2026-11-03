import SwiftUI

/// ★ 저장한 단어 목록. 밀어서 지울 수 있어요.
struct SavedView: View {
    @Environment(Store.self) private var store

    var body: some View {
        List {
            if store.saved.isEmpty {
                Text("저장한 단어가 없어요")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.saved) { e in
                NavigationLink(value: Route.entry(e)) {
                    EntryRow(entry: e)
                }
            }
            .onDelete { store.removeSaved(at: $0) }
        }
        .navigationTitle("단어장")
    }
}
