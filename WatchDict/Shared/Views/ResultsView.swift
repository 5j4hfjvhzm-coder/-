import SwiftUI

/// 검색 결과 목록. 줄마다 첫 뜻을 미리 보여줘서 대부분 탭하지 않아도 돼요.
struct ResultsView: View {
    let query: String

    private enum Phase {
        case loading
        case done([NaverDict.Entry])
        case failed(String)
    }

    @State private var phase: Phase = .loading
    @State private var attempt = 0

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView("찾는 중…")
            case .failed(let message):
                ScrollView {
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.title2)
                        Text(message)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                        Button("다시 시도") { attempt += 1 }
                    }
                }
            case .done(let entries) where entries.isEmpty:
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                    Text("“\(query)” 결과가 없어요")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
            case .done(let entries):
                List(entries) { e in
                    NavigationLink(value: Route.entry(e)) {
                        EntryRow(entry: e)
                    }
                }
            }
        }
        .navigationTitle(query)
        .task(id: attempt) { await load() }
    }

    private func load() async {
        phase = .loading
        do {
            phase = .done(try await NaverDict.search(query, lang: .enko))
        } catch is CancellationError {
            // 화면을 벗어나면 취소돼요
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription
                            ?? "인터넷 연결을 확인해 주세요.\n(아이폰 연결 또는 Wi-Fi)")
        }
    }
}

struct EntryRow: View {
    let entry: NaverDict.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(entry.word)
                    .font(.headline)
                if let sup = entry.superscript {
                    Text(sup)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let preview {
                Text(preview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }

    private var preview: String? {
        guard let g = entry.groups.first else { return nil }
        let means = g.means.prefix(2).joined(separator: "; ")
        if let pos = g.partOfSpeech { return "[\(pos)] \(means)" }
        return means
    }
}
