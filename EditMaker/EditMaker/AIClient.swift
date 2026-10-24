import Foundation
import Security

enum AIProvider: String, CaseIterable, Identifiable {
    case claude, gemini
    var id: String { rawValue }
    var name: String { self == .claude ? "Claude" : "Gemini" }
}

/// API 키는 Mac 키체인에만 저장해요.
enum Keychain {
    private static let service = "EditMaker"

    static func get(_ p: AIProvider) -> String? { read(p.rawValue + "-api-key") }
    static func set(_ p: AIProvider, _ value: String?) { write(p.rawValue + "-api-key", value) }

    private static func read(_ account: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    private static func write(_ account: String, _ value: String?) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(v.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}

enum AIError: LocalizedError {
    case noKey
    case http(Int, String)
    case blocked
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .noKey: return "AI를 쓰려면 설정(⌘,)에서 Claude 또는 Gemini API 키를 넣어 주세요."
        case .http(401, _), .http(403, _): return "API 키가 올바르지 않거나 권한이 없어요. 설정에서 확인해 주세요."
        case .http(429, _): return "AI 사용 한도에 걸렸어요. 잠시 후 다시 시도해 주세요."
        case .http(let code, let msg): return "AI 응답 실패 (\(code)) \(msg)"
        case .blocked: return "AI가 이 요청에 답할 수 없어요."
        case .badResponse(let s): return "AI 답을 이해하지 못했어요. 다시 시도해 주세요. (\(s))"
        }
    }
}

/// 텍스트(+이미지)를 보내고 텍스트 답을 받는 간단한 클라이언트
struct AIClient {
    let provider: AIProvider
    let apiKey: String

    static let claudeModel = "claude-opus-5-5"
    static let geminiModel = "gemini-flash-latest"

    static var preferredProvider: AIProvider {
        get { UserDefaults.standard.string(forKey: "aiProvider").flatMap(AIProvider.init(rawValue:)) ?? .claude }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "aiProvider") }
    }

    /// 고른 AI의 키가 없으면 키가 있는 다른 AI를 써요.
    static func current() -> AIClient? {
        let order = [preferredProvider] + AIProvider.allCases.filter { $0 != preferredProvider }
        for p in order {
            if let k = Keychain.get(p), !k.isEmpty { return AIClient(provider: p, apiKey: k) }
        }
        return nil
    }

    func complete(system: String, text: String, jpegs: [Data] = []) async throws -> String {
        switch provider {
        case .claude: return try await claude(system: system, text: text, jpegs: jpegs)
        case .gemini: return try await gemini(system: system, text: text, jpegs: jpegs)
        }
    }

    private func claude(system: String, text: String, jpegs: [Data]) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 300
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")

        var content: [[String: Any]] = jpegs.map {
            ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": $0.base64EncodedString()]]
        }
        content.append(["type": "text", "text": text])
        let body: [String: Any] = [
            "model": Self.claudeModel,
            "max_tokens": 16000,
            "output_config": ["effort": "medium"],
            "fallbacks": "default",
            "system": system,
            "messages": [["role": "user", "content": content]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard status == 200, let obj else {
            let msg = ((obj?["error"] as? [String: Any])?["message"] as? String) ?? ""
            throw AIError.http(status, msg)
        }
        if obj["stop_reason"] as? String == "refusal" { throw AIError.blocked }
        let blocks = obj["content"] as? [[String: Any]] ?? []
        let out = blocks.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
        guard !out.isEmpty else { throw AIError.badResponse("빈 답") }
        return out
    }

    private func gemini(system: String, text: String, jpegs: [Data]) async throws -> String {
        let key = apiKey.filter { !$0.isWhitespace }
        var req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(Self.geminiModel):generateContent")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 300
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        var parts: [[String: Any]] = jpegs.map { ["inline_data": ["mime_type": "image/jpeg", "data": $0.base64EncodedString()]] }
        parts.append(["text": text])
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": ["maxOutputTokens": 32000, "responseMimeType": "application/json"],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard status == 200, let obj else {
            let msg = ((obj?["error"] as? [String: Any])?["message"] as? String) ?? ""
            throw AIError.http(status, msg)
        }
        if let fb = obj["promptFeedback"] as? [String: Any], fb["blockReason"] != nil { throw AIError.blocked }
        let cand = (obj["candidates"] as? [[String: Any]])?.first
        let ps = ((cand?["content"] as? [String: Any])?["parts"] as? [[String: Any]]) ?? []
        let out = ps.filter { $0["thought"] as? Bool != true }.compactMap { $0["text"] as? String }.joined()
        guard !out.isEmpty else { throw AIError.badResponse("빈 답") }
        return out
    }
}
