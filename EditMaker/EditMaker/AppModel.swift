import AppKit
import AVFoundation
import Foundation
import SwiftUI

enum Step: Int, CaseIterable, Identifiable {
    case materials, style, build, review
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .materials: return "재료"
        case .style: return "스타일"
        case .build: return "만들기"
        case .review: return "검토 · 수정"
        }
    }
    var subtitle: String {
        switch self {
        case .materials: return "레퍼런스와 클립"
        case .style: return "자막 · CC · 효과"
        case .build: return "After Effects 작업"
        case .review: return "보고 고쳐 달라고 하기"
        }
    }
    var symbol: String {
        switch self {
        case .materials: return "square.stack.3d.up.fill"
        case .style: return "wand.and.stars"
        case .build: return "bolt.horizontal.fill"
        case .review: return "play.rectangle.on.rectangle.fill"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    // 재료
    @Published var referenceURL: URL?
    @Published var analysis: ReferenceAnalysis?
    @Published var keyframes: [CGImage] = []
    @Published var referenceHasAudio = false
    @Published var musicURL: URL?
    @Published var clips: [MediaItem] = []
    @Published var presets: [URL] = []

    // 스타일
    @Published var aspect: AspectOption = .vertical
    @Published var cutMode: CutMode = .mix
    @Published var ccPreset = "auto"
    @Published var subtitleStyle = "auto"
    @Published var effectAmount = 0.6
    @Published var bloom = 0.5
    @Published var subtitleText = ""
    @Published var limitLength = false
    @Published var maxLength = 15.0
    @Published var useAIDirector = true
    @Published var renderPreview = true

    // 진행
    @Published var step: Step = .materials
    @Published var isBusy = false
    @Published var status = ""
    @Published var progress: Double? = nil
    @Published var log: [String] = []
    @Published var errorMessage: String?

    // 검토
    @Published var versions: [EditVersion] = []
    @Published var currentVersionID: UUID?
    @Published var draft: EditPlan?
    @Published var chat: [ChatEntry] = []
    @Published var autoRebuild = true

    // 설정
    @Published var aeApps: [AEApp] = []
    @AppStorage("selectedAE") var selectedAEPath = ""

    private var seed: UInt64 = 7
    private var workDir: URL?

    init() {
        aeApps = AERunner.installed()
        FontInstaller.registerDownloaded()
    }

    var selectedAE: AEApp? {
        aeApps.first { $0.url.path == selectedAEPath } ?? aeApps.first
    }

    var currentVersion: EditVersion? { versions.first { $0.id == currentVersionID } }
    var hasAIKey: Bool { AIClient.current() != nil }
    var canGenerate: Bool { referenceURL != nil && analysis != nil && !clips.isEmpty && !isBusy }
    var draftChanged: Bool { draft != nil && draft != currentVersion?.plan }

    // MARK: - 재료

    func setReference(_ url: URL) {
        referenceURL = url
        analysis = nil
        keyframes = []
        Task { await analyzeReference() }
    }

    func analyzeReference() async {
        guard let url = referenceURL else { return }
        isBusy = true
        defer { isBusy = false; progress = nil }
        status = "레퍼런스 분석 중…"
        do {
            let item = try await MediaAnalyzer.loadItem(url)
            referenceHasAudio = item.hasAudio
            let (a, frames) = try await Task.detached(priority: .userInitiated) {
                try await MediaAnalyzer.analyzeReference(url) { msg in
                    Task { @MainActor in self.status = msg }
                }
            }.value
            analysis = a
            keyframes = frames
            status = "분석 완료 · " + a.summary
            addLog("레퍼런스 분석: " + a.summary)
            if a.width > a.height { aspect = .horizontal }
        } catch {
            show(error)
        }
    }

    func addClips(_ urls: [URL]) {
        Task {
            for u in urls {
                let ext = u.pathExtension.lowercased()
                if ext == "ffx" { if !presets.contains(u) { presets.append(u) }; continue }
                if MediaAnalyzer.audioExts.contains(ext) { musicURL = u; continue }
                guard !clips.contains(where: { $0.url == u }) else { continue }
                do { clips.append(try await MediaAnalyzer.loadItem(u)) } catch { show(error) }
            }
        }
    }

    func removeClip(_ c: MediaItem) { clips.removeAll { $0.id == c.id } }

    // MARK: - 만들기

    var options: PlanOptions {
        var o = PlanOptions()
        o.aspect = aspect
        o.cutMode = cutMode
        o.maxLength = limitLength ? maxLength : 0
        o.ccPreset = ccPreset
        o.subtitleStyle = subtitleStyle
        o.effectAmount = effectAmount
        o.bloom = bloom
        o.subtitleLines = subtitleText.components(separatedBy: .newlines)
        o.userPresets = presets.map(\.path)
        o.seed = seed
        return o
    }

    func generate(reshuffle: Bool = false) {
        guard let ref = analysis, let refURL = referenceURL, !clips.isEmpty else { return }
        if reshuffle { seed = UInt64.random(in: 1...UInt64.max / 2) }
        step = .build
        Task {
            var plan = Planner.make(reference: ref, referenceURL: refURL, referenceHasAudio: referenceHasAudio,
                                    musicURL: musicURL, clips: clips, options: options)
            plan = Director.fit(plan, clips: clips)
            var note = "첫 번째 버전"
            if useAIDirector, let client = AIClient.current() {
                isBusy = true
                status = "\(client.provider.name)가 레퍼런스를 보고 자막 스타일·효과를 고르는 중…"
                do {
                    let reply = try await Director.direct(plan: plan, ref: ref, clips: clips, keyframes: keyframes, client: client)
                    plan = reply.plan
                    note = reply.message
                    chat.append(.init(role: .assistant, text: "🎬 " + reply.message))
                    addLog("AI 감독: " + reply.message)
                } catch {
                    addLog("AI 감독을 건너뛰었어요: " + describe(error))
                }
            }
            await build(plan, note: note)
        }
    }

    /// 설계도 → JSX → AE 실행 → (미리보기 렌더) → 새 버전
    func build(_ plan: EditPlan, note: String) async {
        guard let ae = selectedAE else { show(AEError.notInstalled); return }
        isBusy = true
        errorMessage = nil
        progress = nil
        defer { isBusy = false; progress = nil }
        do {
            // 1) 폰트
            if !FontInstaller.missing.isEmpty {
                status = "자막 폰트 준비 중…"
                let n = try await FontInstaller.installMissing { msg in Task { @MainActor in self.status = msg } }
                if n > 0 {
                    addLog("폰트 \(n)개 설치 완료")
                    if isAERunning() {
                        addLog("⚠️ After Effects가 켜져 있었다면 새 폰트를 쓰려면 AE를 한 번 껐다 켜야 할 수 있어요.")
                    }
                }
            }

            // 2) 파일 준비
            let dir = try ensureWorkDir()
            let number = (versions.map(\.number).max() ?? 0) + 1
            let base = "edit_v\(number)"
            let jsxURL = dir.appendingPathComponent(base + ".jsx")
            let aepURL = dir.appendingPathComponent(base + ".aep")
            let doneURL = dir.appendingPathComponent(base + ".done.json")
            let renderBase = dir.appendingPathComponent(base).path
            try Data(Director.encode(plan).utf8).write(to: dir.appendingPathComponent(base + ".plan.json"))
            let jsx = try JSXBuilder.build(plan: plan, aep: aepURL.path, renderBase: renderBase, done: doneURL.path)
            try Data(jsx.utf8).write(to: jsxURL)

            // 3) After Effects
            status = "After Effects에서 v\(number) 만드는 중… (AE 창이 움직여도 놀라지 마세요)"
            addLog("AE 실행: \(ae.name)")
            let result = try await AERunner.runScript(jsxURL, done: doneURL, app: ae)
            result.warnings.forEach { addLog("⚠️ " + $0) }
            addLog("프로젝트 저장: \(aepURL.lastPathComponent)")

            // 4) 미리보기 렌더
            var renderURL: URL? = nil
            if renderPreview && !result.render.isEmpty {
                status = "미리보기 렌더링 중…"
                progress = 0
                let frames = Int(plan.duration * plan.fps)
                try await AERunner.render(project: aepURL, app: ae, totalFrames: frames) { p in
                    Task { @MainActor in self.progress = p }
                }
                if FileManager.default.fileExists(atPath: result.render) { renderURL = URL(fileURLWithPath: result.render) }
                addLog("렌더 완료: \(renderURL?.lastPathComponent ?? "-")")
            }

            let v = EditVersion(number: number, plan: plan, note: note, projectURL: aepURL, renderURL: renderURL)
            versions.append(v)
            currentVersionID = v.id
            draft = plan
            status = "v\(number) 완성! 보고 고칠 부분을 말해 주세요."
            step = .review
            NSApp.requestUserAttention(.informationalRequest)
        } catch {
            show(error)
        }
    }

    private func isAERunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { ($0.localizedName ?? "").hasPrefix("Adobe After Effects") || ($0.bundleIdentifier ?? "").lowercased().contains("aftereffects") }
    }

    private func ensureWorkDir() throws -> URL {
        if let workDir { return workDir }
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Movies")
        let dir = movies.appendingPathComponent("EditMaker").appendingPathComponent("edit-" + f.string(from: Date()))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        workDir = dir
        return dir
    }

    // MARK: - 검토 · 수정

    func select(_ v: EditVersion) {
        currentVersionID = v.id
        draft = v.plan
    }

    /// 채팅 수정 요청 → AI가 설계도 수정 → 다시 만들기
    func sendRevision(_ text: String) {
        let request = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, let base = draft ?? currentVersion?.plan else { return }
        chat.append(.init(role: .user, text: request))
        guard let client = AIClient.current() else {
            chat.append(.init(role: .system, text: AIError.noKey.localizedDescription + " 키 없이도 오른쪽 타임라인에서 직접 고칠 수 있어요."))
            return
        }
        isBusy = true
        status = "\(client.provider.name)가 수정 중…"
        Task {
            do {
                let reply = try await Director.revise(plan: base, request: request, history: chat, ref: analysis, clips: clips, client: client)
                chat.append(.init(role: .assistant, text: reply.message))
                draft = reply.plan
                isBusy = false
                if autoRebuild { await build(reply.plan, note: request) }
                else { status = "수정안 준비됨 · '다시 만들기'를 누르면 반영돼요" }
            } catch {
                isBusy = false
                chat.append(.init(role: .system, text: describe(error)))
                status = ""
            }
        }
    }

    func rebuildFromDraft() {
        guard let d = draft else { return }
        let fixed = Director.fit(d, clips: clips)
        Task { await build(fixed, note: "직접 수정") }
    }

    func openInAE(_ v: EditVersion) {
        guard let p = v.projectURL else { return }
        AERunner.open(project: p, with: selectedAE)
    }

    func reveal(_ v: EditVersion) {
        let target = v.renderURL ?? v.projectURL
        if let target { NSWorkspace.shared.activateFileViewerSelecting([target]) }
    }

    func reset() {
        versions = []
        currentVersionID = nil
        draft = nil
        chat = []
        workDir = nil
        step = .materials
    }

    // MARK: - 기타

    func addLog(_ s: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        log.append("[\(f.string(from: Date()))] " + s)
    }

    func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    func show(_ error: Error) {
        let msg = describe(error)
        errorMessage = msg
        status = "문제가 생겼어요"
        addLog("❌ " + msg)
    }
}

enum JSXBuilder {
    static func build(plan: EditPlan, aep: String, renderBase: String, done: String) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let planJSON = String(data: try enc.encode(plan), encoding: .utf8) ?? "{}"
        let outJSON = String(data: try JSONSerialization.data(withJSONObject: ["aep": aep, "renderBase": renderBase, "done": done]), encoding: .utf8) ?? "{}"
        let s = Templates.jsx
            .replacingOccurrences(of: "__PLAN__", with: planJSON)
            .replacingOccurrences(of: "__OUT__", with: outJSON)
        return asciiEscaped(s)
    }

    /// ExtendScript가 파일 인코딩을 잘못 읽어도 한글이 깨지지 않게 \uXXXX 로 바꿔요.
    static func asciiEscaped(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf16.count)
        for u in s.utf16 {
            if u < 128 { out.append(Character(UnicodeScalar(UInt8(u)))) }
            else { out += String(format: "\\u%04x", u) }
        }
        return out
    }
}
