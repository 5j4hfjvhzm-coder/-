import Foundation

/// 대화 메시지 한 개 (Claude / Gemini 공통)
struct AIMessage {
    var role: ChatMessage.Role
    var text: String
}

/// 답변을 스트리밍으로 받아 onText에 지금까지의 전체 텍스트를 넘기고, 최종 텍스트를 반환해요.
/// 네트워크 작업이라 메인 스레드에 묶지 않아요. onText만 화면(메인)에서 실행돼요.
protocol AIClient: Sendable {
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
            case .http(let code, let msg):
                let detail = msg.isEmpty ? "" : "\n(Google: \(msg))"
                let lower = msg.lowercased()
                if code == 400 && (lower.contains("api key") || lower.contains("api_key")) {
                    return "Gemini API 키가 올바르지 않아요. AI Studio에서 키를 다시 복사해 넣어 보세요." + detail
                }
                switch code {
                case 401, 403:
                    return "Gemini API 키에 권한이 없어요. AI Studio에서 새 키를 만들어 보세요." + detail
                case 404:
                    return "Gemini 모델을 찾지 못했어요. 설정의 모델 칸을 비우고 다시 저장해 보세요." + detail
                case 429:
                    return "Gemini 사용 한도를 넘었어요. 잠시 후 다시 시도하세요." + detail
                default:
                    return "Gemini 응답에 실패했어요. (\(code))" + detail
                }
            case .blocked:
                return "AI가 이 요청에 답할 수 없어요."
            case .stream(let msg):
                return "Gemini 응답에 실패했어요. \(msg)"
            }
        }
    }

    let apiKey: String
    let model: String

    private static let base = "https://generativelanguage.googleapis.com/v1beta/"

    init(apiKey: String, model: String) {
        // 복사할 때 섞여 들어간 공백·줄바꿈을 지워요.
        self.apiKey = apiKey.filter { !$0.isWhitespace && !$0.isNewline }
        self.model = model
    }

    func stream(system: String? = nil, messages: [AIMessage], onText: @escaping @MainActor (String) -> Void) async throws -> String {
        do {
            return try await streamOnce(model: model, system: system, messages: messages, onText: onText)
        } catch APIError.http(404, let msg) {
            // 모델 이름이 없으면, 이 키로 쓸 수 있는 Flash 모델을 찾아서 한 번 더 시도해요.
            guard let alt = try? await findFlashModel(), alt != model else { throw APIError.http(404, msg) }
            AI.geminiModel = alt
            return try await streamOnce(model: alt, system: system, messages: messages, onText: onText)
        }
    }

    private func request(_ path: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: Self.base + path) else { throw APIError.http(404, "") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        // AQ. 형식 키는 주소(?key=)가 아니라 이 헤더로만 보내야 해요.
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        return req
    }

    private func streamOnce(model: String, system: String?, messages: [AIMessage], onText: @escaping @MainActor (String) -> Void) async throws -> String {
        let name = model.hasPrefix("models/") ? String(model.dropFirst(7)) : model
        let path = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        var req = try request("models/\(path):streamGenerateContent?alt=sse", method: "POST")

        var body: [String: Any] = [
            "contents": messages.map { m -> [String: Any] in
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
            throw APIError.http(status, Self.errorMessage(raw) ?? String(decoding: raw.prefix(200), as: UTF8.self))
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
                        await onText(text)
                    }
                }
            }
            if let reason = cand["finishReason"] as? String, ["SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII"].contains(reason) {
                throw APIError.blocked
            }
        }
        return text
    }

    /// 이 키로 쓸 수 있는 모델 중 가장 최신의 일반 Flash 모델 이름을 찾아요.
    private func findFlashModel() async throws -> String? {
        let (data, response) = try await URLSession.shared.data(for: try request("models?pageSize=1000"))
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = obj["models"] as? [[String: Any]] else { return nil }
        let names: [String] = models.compactMap { m in
            guard let name = m["name"] as? String,
                  (m["supportedGenerationMethods"] as? [String])?.contains("generateContent") == true else { return nil }
            return name.hasPrefix("models/") ? String(name.dropFirst(7)) : name
        }
        let skip = ["lite", "live", "image", "tts", "audio", "embed", "vision", "8b"]
        func version(_ n: String) -> Double {
            guard let r = n.range(of: #"\d+(\.\d+)?"#, options: .regularExpression) else { return 0 }
            return Double(n[r]) ?? 0
        }
        func pick(_ list: [String]) -> String? {
            list.sorted { a, b in
                let pa = a.contains("preview") || a.contains("exp"), pb = b.contains("preview") || b.contains("exp")
                if pa != pb { return !pa }
                return version(a) > version(b)
            }.first
        }
        let flash = names.filter { n in n.contains("gemini") && n.contains("flash") && !skip.contains { n.contains($0) } }
        return pick(flash) ?? pick(names.filter { $0.contains("gemini") })
    }

    private static func errorMessage(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any] else { return nil }
        return err["message"] as? String
    }
}
