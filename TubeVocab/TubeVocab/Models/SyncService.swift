import Foundation
import Observation

/// iCloud Drive(또는 아무 공유 폴더)에 둔 파일 하나로 아이폰·아이패드·맥의 단어장을 맞춘다.
/// 앱에 iCloud 기능을 넣지 않아서 무료 Apple ID 로도 쓸 수 있다:
/// 각 기기에서 같은 폴더를 한 번 골라 두면, 그 안의 TubeVocab-words.json 을 읽어 합치고 다시 쓴다.

/// 동기화 폴더 안의 파일 이름
let syncFileName = "TubeVocab-words.json"

/// 동기화 파일 내용
struct SyncFile: Codable, Equatable {
    var version = 1
    var words: [SavedWord] = []
    /// 지운 단어 id → 지운 시각(ms)
    var deleted: [String: Int] = [:]
}

enum SyncMerge {
    /// 지운 기록은 90일 지나면 버린다
    static let tombstoneMaxAgeMs = 90 * 24 * 60 * 60 * 1000

    /// 두 단어장을 합친다.
    /// - 같은 id 면 더 최근에 바뀐 쪽
    /// - 지운 시각이 단어의 마지막 수정보다 늦으면 지운다 (지운 뒤 다시 고친 단어는 살아남음)
    static func merge(local: [SavedWord], localDeleted: [String: Int],
                      remote: SyncFile?, now: Int = nowMs()) -> SyncFile {
        var deleted = localDeleted
        for (id, t) in remote?.deleted ?? [:] { deleted[id] = max(deleted[id] ?? 0, t) }
        deleted = deleted.filter { now - $0.value < tombstoneMaxAgeMs }

        var byID: [UUID: SavedWord] = [:]
        for w in (remote?.words ?? []) + local {
            if let old = byID[w.id], old.modified >= w.modified { continue }
            byID[w.id] = w
        }
        let words = byID.values
            .filter { w in (deleted[w.id.uuidString] ?? Int.min) < w.modified }
            .sorted { $0.createdAt > $1.createdAt }
        return SyncFile(words: words, deleted: deleted)
    }
}

@MainActor
@Observable
final class SyncService {
    private static let bookmarkKey = "syncFolderBookmark"

    private(set) var folderName: String?
    private(set) var lastSync: Date?
    private(set) var syncing = false
    private(set) var error: String?

    @ObservationIgnored private let vocab: VocabStore
    @ObservationIgnored private var folderURL: URL?
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var poll: Task<Void, Never>?

    var isConnected: Bool { folderURL != nil }

    init(vocab: VocabStore) {
        self.vocab = vocab
        if let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) {
                folderURL = url
                folderName = url.lastPathComponent
                if stale { saveBookmark(url) }
            }
        }
        vocab.onLocalChange = { [weak self] in self?.scheduleSync() }
    }

    // MARK: 폴더 연결

    /// 파일 선택기로 고른 폴더를 동기화 폴더로
    func connect(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard saveBookmark(url) else {
            error = "이 폴더는 기억할 수 없어요. 다른 폴더를 골라 주세요."
            return
        }
        folderURL = url
        folderName = url.lastPathComponent
        error = nil
        syncNow()
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        folderURL = nil
        folderName = nil
        lastSync = nil
        error = nil
    }

    @discardableResult
    private func saveBookmark(_ url: URL) -> Bool {
        guard let data = try? url.bookmarkData() else { return false }
        UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        return true
    }

    // MARK: 동기화

    /// 단어장이 바뀌면 잠깐 기다렸다가 (연달아 바뀌는 것을 한 번에) 동기화
    func scheduleSync() {
        guard isConnected else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.syncNow()
        }
    }

    /// 앱이 앞에 있는 동안 30초마다 다른 기기의 변경을 확인
    func startPolling() {
        syncNow()
        poll?.cancel()
        poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                self?.syncNow()
            }
        }
    }

    func stopPolling() {
        poll?.cancel()
        poll = nil
    }

    func syncNow() {
        guard let folder = folderURL, !syncing else { return }
        syncing = true
        let localWords = vocab.words
        let localDeleted = vocab.deleted
        Task {
            let result = await Task.detached(priority: .utility) {
                Self.syncFile(in: folder, local: localWords, localDeleted: localDeleted)
            }.value
            syncing = false
            switch result {
            case .success(let merged):
                error = nil
                lastSync = Date()
                // 그 사이 이 기기에서 바뀐 게 없을 때만 반영 (바뀌었으면 곧 다시 동기화된다)
                if vocab.words == localWords && vocab.deleted == localDeleted
                    && (merged.words != localWords || merged.deleted != localDeleted) {
                    vocab.replaceFromSync(words: merged.words, deleted: merged.deleted)
                }
            case .failure(let e):
                error = e.localizedDescription
            }
        }
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// 폴더의 동기화 파일을 읽어 합치고 다시 쓴다 (다른 기기와 겹치지 않게 파일 조정자 사용)
    nonisolated private static func syncFile(in folder: URL, local: [SavedWord],
                                             localDeleted: [String: Int]) -> Result<SyncFile, Failure> {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        let file = folder.appending(path: syncFileName)
        let fm = FileManager.default

        // iCloud 에만 있고 아직 내려받지 않은 파일이면 내려받기 요청
        if fm.isUbiquitousItem(at: file) {
            try? fm.startDownloadingUbiquitousItem(at: file)
        }

        var coordError: NSError?
        var result: Result<SyncFile, Failure> = .failure(Failure(message: "동기화 파일을 열지 못했어요."))
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forMerging, error: &coordError) { url in
            var remote: SyncFile?
            if fm.fileExists(atPath: url.path) {
                guard let data = try? Data(contentsOf: url) else {
                    result = .failure(Failure(message: "동기화 파일을 아직 내려받는 중이에요. 잠시 뒤 다시 시도해요."))
                    return
                }
                guard let decoded = try? JSONDecoder().decode(SyncFile.self, from: data) else {
                    result = .failure(Failure(message: "동기화 파일(\(syncFileName))을 읽을 수 없어요. 다른 앱이 바꾼 것 같아요."))
                    return
                }
                remote = decoded
            }
            let merged = SyncMerge.merge(local: local, localDeleted: localDeleted, remote: remote)
            if merged != remote {
                do {
                    let enc = JSONEncoder()
                    enc.outputFormatting = [.sortedKeys]
                    try enc.encode(merged).write(to: url, options: .atomic)
                } catch {
                    result = .failure(Failure(message: "동기화 폴더에 쓰지 못했어요: \(error.localizedDescription)"))
                    return
                }
            }
            result = .success(merged)
        }
        if let coordError {
            return .failure(Failure(message: "동기화 파일을 열지 못했어요: \(coordError.localizedDescription)"))
        }
        return result
    }
}
