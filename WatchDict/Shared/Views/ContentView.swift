import SwiftUI

enum Route: Hashable {
    case results(String)
    case entry(NaverDict.Entry)
    case saved
}

/// 첫 화면: 검색창, 단어장, 최근 검색
struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var path: [Route] = []
    @State private var query = ""

    var body: some View {
        NavigationStack(path: $path) {
            List {
                TextField("단어 검색", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { search(query) }

                if !store.saved.isEmpty {
                    NavigationLink(value: Route.saved) {
                        Label("단어장 \(store.saved.count)", systemImage: "star.fill")
                    }
                }

                if !store.recents.isEmpty {
                    Section("최근 검색") {
                        ForEach(store.recents, id: \.self) { q in
                            Button {
                                search(q)
                            } label: {
                                Label(q, systemImage: "clock.arrow.circlepath")
                            }
                        }
                        .onDelete { store.removeRecents(at: $0) }

                        Button("기록 모두 지우기", role: .destructive) {
                            store.clearRecents()
                        }
                        .font(.footnote)
                    }
                } else {
                    Text("영어나 한글로 검색하면 네이버 영한사전에서 뜻을 찾아요. 받아쓰기·손글씨도 돼요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("영어사전")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .results(let q): ResultsView(query: q)
                case .entry(let e): EntryDetailView(entry: e)
                case .saved: SavedView()
                }
            }
        }
    }

    private func search(_ raw: String) {
        // 받아쓰기는 "Apple." 처럼 끝에 문장부호를 붙이기도 해요
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !q.isEmpty else { return }
        store.addRecent(q)
        query = ""
        path.append(.results(q))
    }
}
