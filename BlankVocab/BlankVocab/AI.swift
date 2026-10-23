import Foundation

/// 대화 메시지 한 개 (Claude / Gemini 공통)
struct AIMessage {
    var role: ChatMessage.Role
    var text: String
}

/// 답변을 스트리밍으로 받아 onText에 지금까지의 전체 텍스트를 넘기고, 최종 텍스트를 반환해요.
@MainActor
protocol AIClient {
    func stream(system: String?, messages: [AIMessage], onText: @escaping @MainActor (String) -> Void) async throws -> String
}

extension AIClient {
    func stream(messages: [AIMessage], onText: @escaping @MainActor (String) -> Void) async throws -> String {
        try await stream(system: nil, messages: messages, onText: onText)
    }
}

enum AIProvider: String, CaseIterable, Identifiable {
    case claude, gemini

    var id: String { rawValue }

    var name: String {
        switch self {
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        }
    }
}

/// 설정에서 고른 AI와 키로 클라이언트를 만들어요.
enum AI {
    private static let providerKey = "aiProvider"
    private static let geminiModelKey = "geminiModel"
    static let defaultGeminiModel = "gemini-flash-latest"

    static var provider: AIProvider {
        get { UserDefaults.standard.string(forKey: providerKey).flatMap(AIProvider.init(rawValue:)) ?? .claude }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }

    static var geminiModel: String {
        get {
            let m = UserDefaults.standard.string(forKey: geminiModelKey)?.trimmingCharacters(in: .whitespaces) ?? ""
            return m.isEmpty ? defaultGeminiModel : m
        }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: geminiModelKey) }
    }

    static func key(for p: AIProvider) -> String? {
        switch p {
        case .claude: return Keychain.apiKey
        case .gemini: return Keychain.geminiKey
        }
    }

    static func client(for p: AIProvider) -> AIClient? {
        guard let k = key(for: p), !k.isEmpty else { return nil }
        switch p {
        case .claude: return ClaudeClient(apiKey: k)
        case .gemini: return GeminiClient(apiKey: k, model: geminiModel)
        }
    }

    /// 지금 고른 AI. 고른 쪽 키가 없으면 키가 있는 다른 AI를 써요. 둘 다 없으면 nil.
    static func current() -> AIClient? {
        client(for: provider) ?? AIProvider.allCases.lazy.compactMap { client(for: $0) }.first
    }

    static let missingKeyMessage = "AI 기능을 쓰려면 첫 화면 오른쪽 위 ⚙︎ 설정에서 Claude 또는 Gemini API 키를 입력하세요."

    static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "AI 응답에 실패했어요. 잠시 후 다시 시도하세요."
    }
}

/// Gemini API(generativelanguage.googleapis.com)를 스트리밍(SSE)으로 호출해요.
struct GeminiClient: AIClient {
    enum APIError: LocalizedError {
        case http(Int, String)
        case blocked
        case stream(String)

        var errorDescription: String? {
            switch self {
            case .http(400, let msg) where msg.localizedCaseInsensitiveContains("api key"):
                return "Gemini API 키가 올바르지 않아요. 설정에서 확인하세요."
            case .http(401, _), .http(403, _):
                return "Gemini API 키가 올바르지 않거나 권한이 없어요. 설정에서 확인하세요."
            case .http(404, _):
                return "Gemini 모델을 찾지 못했어요. 설정에서 모델 이름을 확인하세요."
            case .http(429, _):
                return "Gemini 요청 한도를 넘었어요. 잠시 후 다시 시도하세요."
            case .http(let code, let msg):
                return "AI 응답에 실패했어요. (\(code)) \(msg)"
            case .blocked:
                return "AI가 이 요청에 답할 수 없어요."
            case .stream(let msg):
                return "AI 응답에 실패했어요. \(msg)"
            }
        }
    }

    let apiKey: String
    let model: String

    func stream(system: String? = nil, messages: [AIMessage], onText: @escaping @MainActor (String) -> Void) async throws -> String {
        let path = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(path):streamGenerateContent?alt=sse") else {
            throw APIError.http(404, "")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        var body: [String: Any] = [
            "contents": messages.map { m in
                ["role": m.role == .user ? "user" : "model", "parts": [["text": m.text]]]
            },
            "generationConfig": ["maxOutputTokens": 8192],
        ]
        if let system { body["systemInstruction"] = ["parts": [["text": system]]] }
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
                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
            if let msg = Self.errorMessage(d) { throw APIError.stream(msg) }
            if let fb = obj["promptFeedback"] as? [String: Any], fb["blockReason"] != nil { throw APIError.blocked }
            guard let cand = (obj["candidates"] as? [[String: Any]])?.first else { continue }
            if let parts = (cand["content"] as? [String: Any])?["parts"] as? [[String: Any]] {
                for p in parts where p["thought"] as? Bool != true {
                    if let t = p["text"] as? String, !t.isEmpty {
                        text += t
                        onText(text)
                    }
                }
            }
            if let reason = cand["finishReason"] as? String, ["SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII"].contains(reason) {
                throw APIError.blocked
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
