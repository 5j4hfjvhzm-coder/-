import AppKit
import CoreText
import Foundation

struct AEApp: Identifiable, Hashable {
    let url: URL
    var id: String { url.path }
    /// 예: "Adobe After Effects 2025"
    var name: String { url.deletingPathExtension().lastPathComponent }
    var aerender: URL { url.deletingLastPathComponent().appendingPathComponent("aerender") }
}

struct AEResult: Decodable {
    var ok: Bool
    var message: String
    var render: String
    var warnings: [String]
}

enum AEError: LocalizedError {
    case notInstalled
    case script(String)
    case noResult
    case render(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "After Effects를 찾지 못했어요. /Applications 에 Adobe After Effects가 설치돼 있는지 확인해 주세요."
        case .script(let msg):
            if msg.contains("-1743") || msg.lowercased().contains("not authorized") {
                return "After Effects를 제어할 권한이 없어요. 시스템 설정 › 개인정보 보호 및 보안 › 자동화 에서 '에딧 메이커' → After Effects 를 켜 주세요."
            }
            return "After Effects 스크립트 실행 실패: \(msg)"
        case .noResult:
            return "After Effects가 결과를 남기지 않았어요. AE 설정 › 스크립팅 및 표현식 › '스크립트가 파일을 쓰고 네트워크에 액세스하도록 허용'을 켜 주세요."
        case .render(let msg):
            return "미리보기 렌더링 실패: \(msg)"
        }
    }
}

/// After Effects 실행·스크립트 전달·렌더링
enum AERunner {
    static func installed() -> [AEApp] {
        let fm = FileManager.default
        var found: [AEApp] = []
        for root in ["/Applications", NSHomeDirectory() + "/Applications"] {
            guard let dirs = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for d in dirs where d.hasPrefix("Adobe After Effects") {
                let dir = URL(fileURLWithPath: root).appendingPathComponent(d)
                if d.hasSuffix(".app") {
                    found.append(AEApp(url: dir))
                } else if let inner = try? fm.contentsOfDirectory(atPath: dir.path) {
                    for a in inner where a.hasPrefix("Adobe After Effects") && a.hasSuffix(".app") {
                        found.append(AEApp(url: dir.appendingPathComponent(a)))
                    }
                }
            }
        }
        return found.sorted { $0.name > $1.name }
    }

    /// AppleScript로 AE에 JSX를 실행시키고, 스크립트가 남긴 결과 파일을 읽어요.
    static func runScript(_ jsx: URL, done: URL, app: AEApp) async throws -> AEResult {
        try? FileManager.default.removeItem(at: done)
        let jsPath = jsx.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let js = "$.evalFile(new File('\(jsPath)'));"
        let asString = js.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let appName = app.name.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        with timeout of 3600 seconds
            tell application "\(appName)"
                activate
                DoScript "\(asString)"
            end tell
        end timeout
        """
        let (code, _, err) = try await run(URL(fileURLWithPath: "/usr/bin/osascript"), ["-e", script])
        if code != 0 && !FileManager.default.fileExists(atPath: done.path) {
            throw AEError.script(err.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // 스크립트가 늦게 끝나는 경우를 대비해 잠깐 기다려요.
        for _ in 0..<120 {
            if let data = try? Data(contentsOf: done), let r = try? JSONDecoder().decode(AEResult.self, from: data) {
                if !r.ok { throw AEError.script(r.message) }
                return r
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw AEError.noResult
    }

    /// aerender로 렌더 대기열을 렌더링해요. progress는 0~1.
    static func render(project: URL, app: AEApp, totalFrames: Int, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard FileManager.default.isExecutableFile(atPath: app.aerender.path) else {
            throw AEError.render("aerender를 찾지 못했어요 (\(app.aerender.path))")
        }
        let regex = try NSRegularExpression(pattern: #"PROGRESS:.*\((\d+)\)"#)
        let (code, out, err) = try await run(app.aerender, ["-project", project.path]) { line in
            let ns = line as NSString
            if let m = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
               let frame = Double(ns.substring(with: m.range(at: 1))) {
                progress(min(frame / Double(max(totalFrames, 1)), 1))
            }
        }
        if code != 0 {
            let tail = (out + "\n" + err).split(separator: "\n").suffix(4).joined(separator: "\n")
            throw AEError.render(tail)
        }
    }

    /// 프로세스 실행. 줄 단위 출력 콜백 지원.
    static func run(_ exe: URL, _ args: [String], onLine: (@Sendable (String) -> Void)? = nil) async throws -> (Int32, String, String) {
        try await withCheckedThrowingContinuation { cont in
            let p = Process()
            p.executableURL = exe
            p.arguments = args
            let outPipe = Pipe(), errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe
            let box = OutputBox()
            outPipe.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData
                guard !d.isEmpty, let s = String(data: d, encoding: .utf8) else { return }
                box.appendOut(s)
                if let onLine { s.split(separator: "\n").forEach { onLine(String($0)) } }
            }
            errPipe.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData
                guard !d.isEmpty, let s = String(data: d, encoding: .utf8) else { return }
                box.appendErr(s)
            }
            p.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                let restOut = outPipe.fileHandleForReading.readDataToEndOfFile()
                let restErr = errPipe.fileHandleForReading.readDataToEndOfFile()
                box.appendOut(String(data: restOut, encoding: .utf8) ?? "")
                box.appendErr(String(data: restErr, encoding: .utf8) ?? "")
                cont.resume(returning: (proc.terminationStatus, box.out, box.err))
            }
            do { try p.run() } catch { cont.resume(throwing: error) }
        }
    }

    static func open(project: URL, with app: AEApp?) {
        if let app {
            NSWorkspace.shared.open([project], withApplicationAt: app.url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(project)
        }
    }
}

private final class OutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _out = "", _err = ""
    var out: String { lock.lock(); defer { lock.unlock() }; return _out }
    var err: String { lock.lock(); defer { lock.unlock() }; return _err }
    func appendOut(_ s: String) { lock.lock(); _out += s; lock.unlock() }
    func appendErr(_ s: String) { lock.lock(); _err += s; lock.unlock() }
}

/// Google Fonts에서 무료 한글 폰트를 받아 ~/Library/Fonts 에 설치해요.
enum FontInstaller {
    static var folder: URL { URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Fonts") }

    static func isInstalled(_ f: FontAsset) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(f.file).path) || NSFont(name: f.id, size: 12) != nil
    }

    static var missing: [FontAsset] { Catalog.fonts.filter { !isInstalled($0) } }

    /// 설치한 개수를 돌려줘요.
    static func installMissing(progress: @escaping @Sendable (String) -> Void) async throws -> Int {
        let todo = missing
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var n = 0
        for f in todo {
            progress("폰트 받는 중… \(f.name)")
            let (tmp, resp) = try await URLSession.shared.download(from: f.url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { continue }
            let dest = folder.appendingPathComponent(f.file)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmp, to: dest)
            CTFontManagerRegisterFontsForURL(dest as CFURL, .process, nil)
            n += 1
        }
        return n
    }

    /// 앱 실행 중에 미리보기에서 쓸 수 있게 이미 받은 폰트를 등록
    static func registerDownloaded() {
        for f in Catalog.fonts {
            let u = folder.appendingPathComponent(f.file)
            if FileManager.default.fileExists(atPath: u.path) {
                CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil)
            }
        }
    }
}
