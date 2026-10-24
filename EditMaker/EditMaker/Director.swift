import AppKit
import Foundation

/// AI 감독: 처음엔 자막 스타일·효과를 레퍼런스에 맞게 골라 주고,
/// 영상이 나온 뒤에는 "자막 더 크게" 같은 수정 요청을 설계도(EditPlan)에 반영해요.
enum Director {
    struct Reply: Decodable {
        var message: String
        var plan: EditPlan
    }

    static var system: String {
        let styles = Catalog.styles.map { "- \($0.id): \($0.name) — \($0.detail) (기본 폰트 \($0.font))" }.joined(separator: "\n")
        let trans = Catalog.transitions.map { "- \($0.id): \($0.name) — \($0.detail)" }.joined(separator: "\n")
        let ccs = Catalog.ccPresets.map { "- \($0.id): \($0.name) — \($0.detail)" }.joined(separator: "\n")
        let fonts = Catalog.fonts.map { "- \($0.id) (\($0.name))" }.joined(separator: "\n")
        return """
        너는 틱톡/릴스 K-pop 팬 "edit" 영상 전문 편집 감독이야. After Effects로 만들어질 edit의 설계도(JSON)를 다룬다.
        edit 특유의 느낌: 비트에 딱딱 맞는 빠른 컷, 줌 펀치·플래시·흔들림, 몽환적인 글로우 색보정(cc), 네온/번지는 자막.

        설계도 필드:
        - width, height, fps, duration(초)
        - music: {path, offset} — 바꾸지 마.
        - cc: {preset, intensity 0~1, bloom 0~1(살짝 번지는 글로우), grain 0~1, vignette 0~1, userPresets[] — 바꾸지 마}
        - segments[]: {id, clip(파일 경로, 주어진 클립 목록 안에서만), clipIn(클립의 몇 초부터), start, end, speed(1=원래, 0.5=슬로우), transition, shake(bool), push(0~0.3 천천히 줌인)}
          · segments는 0초부터 duration까지 빈틈없이, 겹치지 않게 이어져야 해.
          · clipIn + (end-start)*speed 가 그 클립 길이를 넘으면 안 돼.
          · 컷 경계는 가능하면 beats 목록의 시각에 맞춰.
        - subtitles[]: {id, text(줄바꿈은 \\n), start, end, style, font, size(px), color(#RRGGBB 글자색), accent(#RRGGBB 테두리·글로우색), x, y(0~1, 0.5가 중앙)}
        - beats: 음악 비트 시각 — 참고만 하고 바꾸지 마.

        자막 style:
        \(styles)

        transition:
        \(trans)

        cc preset:
        \(ccs)

        설치된 폰트(font 값):
        \(fonts)

        규칙:
        - 요청한 부분만 고치고 나머지는 최대한 그대로 둬.
        - 자막 내용(text)은 사용자가 바꾸라고 할 때만 바꿔.
        - 답은 반드시 JSON 하나만: {"message": "무엇을 바꿨는지 한국어로 1~3문장", "plan": {설계도 전체}}
        - 코드블록이나 다른 설명 없이 JSON만 출력해.
        """
    }

    static func clipList(_ clips: [MediaItem]) -> String {
        clips.map { c in
            c.isStill ? "- \(c.url.path) (사진)" : String(format: "- %@ (%.2f초)", c.url.path, c.duration)
        }.joined(separator: "\n")
    }

    /// 처음 만들 때: 규칙으로 만든 초안을 AI가 레퍼런스 장면을 보고 다듬어요.
    static func direct(plan: EditPlan, ref: ReferenceAnalysis, clips: [MediaItem], keyframes: [CGImage], client: AIClient) async throws -> Reply {
        let text = """
        첨부 이미지는 레퍼런스 edit 영상의 장면들이야. 분석: \(ref.summary)

        사용할 클립:
        \(clipList(clips))

        아래 초안을 레퍼런스 느낌에 맞게 다듬어 줘.
        - 자막마다 어울리는 style, font, 색(color/accent), 크기, 위치를 골라 (레퍼런스 자막 색감·분위기를 참고).
        - 컷의 transition/shake/push 를 비트 세기와 분위기에 맞게 조절해.
        - cc preset/bloom 도 레퍼런스 색감에 맞게.
        - 컷 타이밍(start/end)과 clip 배치는 크게 바꾸지 마.

        초안:
        \(encode(plan))
        """
        return try await ask(client: client, text: text, jpegs: keyframes.compactMap(jpeg), clips: clips, original: plan)
    }

    /// 영상 검토 후 수정 요청
    static func revise(plan: EditPlan, request: String, history: [ChatEntry], ref: ReferenceAnalysis?, clips: [MediaItem], client: AIClient) async throws -> Reply {
        let recent = history.suffix(8).compactMap { e -> String? in
            switch e.role {
            case .user: return "사용자: \(e.text)"
            case .assistant: return "감독: \(e.text)"
            case .system: return nil
            }
        }.joined(separator: "\n")
        let text = """
        \(ref.map { "레퍼런스 분석: \($0.summary)\n" } ?? "")
        사용할 클립:
        \(clipList(clips))

        지금까지 대화:
        \(recent.isEmpty ? "(없음)" : recent)

        현재 설계도:
        \(encode(plan))

        사용자의 새 수정 요청: \(request)
        """
        return try await ask(client: client, text: text, jpegs: [], clips: clips, original: plan)
    }

    private static func ask(client: AIClient, text: String, jpegs: [Data], clips: [MediaItem], original: EditPlan) async throws -> Reply {
        let raw = try await client.complete(system: system, text: text, jpegs: jpegs)
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else {
            throw AIError.badResponse("JSON 없음")
        }
        let json = String(raw[start...end])
        var reply: Reply
        do {
            reply = try JSONDecoder().decode(Reply.self, from: Data(json.utf8))
        } catch {
            throw AIError.badResponse("설계도 형식 오류")
        }
        // 바꾸면 안 되는 것들은 원래대로
        reply.plan.music = original.music
        reply.plan.beats = original.beats
        reply.plan.cc.userPresets = original.cc.userPresets
        reply.plan = fit(reply.plan, clips: clips)
        return reply
    }

    /// 범위를 정리하고, 클립 길이를 넘는 구간을 고쳐요.
    static func fit(_ plan: EditPlan, clips: [MediaItem]) -> EditPlan {
        var p = plan.sanitized(allowedClips: Set(clips.map { $0.url.path }))
        let byPath = Dictionary(clips.map { ($0.url.path, $0) }, uniquingKeysWith: { a, _ in a })
        for i in p.segments.indices {
            guard let c = byPath[p.segments[i].clip], !c.isStill else { continue }
            let len = p.segments[i].length
            if len * p.segments[i].speed > c.duration {
                p.segments[i].speed = max(0.1, c.duration / len * 0.98)
            }
            let need = len * p.segments[i].speed
            if p.segments[i].clipIn + need > c.duration {
                p.segments[i].clipIn = max(0, c.duration - need - 0.01)
            }
        }
        return p
    }

    static func encode(_ plan: EditPlan) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? enc.encode(plan)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func jpeg(_ image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75])
    }
}
