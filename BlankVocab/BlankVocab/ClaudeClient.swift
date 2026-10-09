import Foundation

/// Claude Messages API를 스트리밍(SSE)으로 호출하는 작은 클라이언트.
/// Swift용 공식 SDK가 없어서 URLSession으로 직접 호출해요.
struct ClaudeClient {
    struct Message {
        var role: ChatMessage.Role
        var text: String
    }

    enum APIError: LocalizedError {
        case http(Int, String)
        case refusal
        case stream(String)

        var errorDescription: String? {
            switch self {
            case .http(401, _): return "API 키가 올바르지 않아요. 설정에서 확인하세요."
            case .http(429, _): return "요청이 많아요. 잠시 후 다시 시도하세요."
            case .http(let code, let msg): return "AI 응답에 실패했어요. (\(code)) \(msg)"
            case .refusal: return "AI가 이 요청에 답할 수 없어요."
            case .stream(let msg): return "AI 응답에 실패했어요. \(msg)"
            }
        }
    }

    static let model = "claude-opus-5-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    let apiKey: String

    /// 설정에 저장된 키로 클라이언트를 만들어요. 키가 없으면 nil.
    static func fromSettings() -> ClaudeClient? {
        guard let key = Keychain.apiKey, !key.isEmpty else { return nil }
        return ClaudeClient(apiKey: key)
    }

    /// 답변을 스트리밍으로 받아 onText에 지금까지의 전체 텍스트를 넘겨요. 최종 텍스트를 반환해요.
    @MainActor
    func stream(system: String? = nil, messages: [Message], onText: @escaping @MainActor (String) -> Void) async throws -> String {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // 안전 분류기가 거절하면 서버가 자동으로 다른 모델로 이어서 답하게 해요.
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")

        var body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 4096,
            "stream": true,
            // 짧은 대화/설명이라 응답 속도를 위해 effort를 낮춰요.
            "output_config": ["effort": "low"],
            "fallbacks": "default",
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.text] },
        ]
        if let system { body["system"] = system }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            var raw = Data()
            for try await b in bytes { raw.append(b) }
            throw APIError.http(status, Self.errorMessage(raw) ?? "")
        }

        var text = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let d = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let type = obj["type"] as? String else { continue }
            switch type {
            case "content_block_delta":
                if let delta = obj["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let t = delta["text"] as? String {
                    text += t
                    onText(text)
                }
            case "message_delta":
                if let delta = obj["delta"] as? [String: Any], delta["stop_reason"] as? String == "refusal" {
                    throw APIError.refusal
                }
            case "error":
                throw APIError.stream(Self.errorMessage(d) ?? "")
            default:
                break
            }
        }
        return text
    }

    private static func errorMessage(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any] else { return nil }
        return err["message"] as? String
    }
}
