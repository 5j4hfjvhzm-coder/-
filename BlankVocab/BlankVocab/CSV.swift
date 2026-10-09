import Foundation

enum CSV {
    /// 따옴표("...")와 줄바꿈을 지원하는 간단한 CSV 파서
    static func parse(_ input: String) -> [[String]] {
        var text = input
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        var rows: [[String]] = []
        var row: [String] = []
        var cell = ""
        var quoted = false
        var chars = Array(text.unicodeScalars)
        var i = 0
        // \r\n 을 하나의 줄바꿈으로 처리하기 위해 스칼라 단위로 순회
        while i < chars.count {
            let h = chars[i]
            if quoted {
                if h == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        cell.unicodeScalars.append("\"")
                        i += 1
                    } else {
                        quoted = false
                    }
                } else {
                    cell.unicodeScalars.append(h)
                }
            } else if h == "\"" {
                quoted = true
            } else if h == "," {
                row.append(cell)
                cell = ""
            } else if h == "\n" || h == "\r" {
                if h == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
                row.append(cell)
                rows.append(row)
                row = []
                cell = ""
            } else {
                cell.unicodeScalars.append(h)
            }
            i += 1
        }
        if !cell.isEmpty || !row.isEmpty {
            row.append(cell)
            rows.append(row)
        }
        chars.removeAll()
        return rows.filter { $0.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    /// 첫 줄의 열 이름(단어/word, 의미/뜻/meaning, 예문/example, 품사/pos, 마크/b)을 보고 단어 목록으로 바꿔요.
    static func words(from rows: [[String]]) -> [Word] {
        guard let header = rows.first else { return [] }
        let H = header.map { h -> String in
            var s = h
            if let r = s.range(of: #"\(.*\)"#, options: .regularExpression) { s.removeSubrange(r) }
            return s.trimmingCharacters(in: .whitespaces).lowercased()
        }
        func col(_ names: [String], _ def: Int) -> Int {
            H.firstIndex(where: { names.contains($0) }) ?? def
        }
        let ib = col(["마크", "b"], -1)
        let iw = col(["단어", "word"], 0)
        let im = col(["의미", "뜻", "meaning"], 1)
        let ie = col(["예문", "example"], -1)
        let ip = col(["품사", "pos"], -1)

        func get(_ r: [String], _ i: Int) -> String {
            i >= 0 && i < r.count ? r[i].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        }
        return rows.dropFirst().compactMap { r in
            let w = get(r, iw)
            guard !w.isEmpty else { return nil }
            let mark = get(r, ib)
            return Word(w: w, m: get(r, im), e: get(r, ie), p: get(r, ip), star: !mark.isEmpty && mark != "0")
        }
    }

    /// UTF-8로 읽고, 실패하면 EUC-KR(엑셀 한글 CSV)로 읽어요.
    static func decode(_ data: Data) -> String? {
        if let s = String(data: data, encoding: .utf8) { return s }
        let euckr = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue))
        return String(data: data, encoding: String.Encoding(rawValue: euckr))
    }

    /// 웹 버전과 같은 열 구성으로 내보내기
    static func export(_ book: Book) -> String {
        func q(_ v: String) -> String { "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let today = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        var lines = ["단어(W),의미(M),성별(G),발음(P),품사(POS),예문(E),파생어(DER),유의어(SIM),동의어(S),반의어(A),설명(D),마크(B),날짜(C),이미지(I)"]
        for w in book.words {
            lines.append([q(w.w), q(w.m), "", "", q(w.p), q(w.e), "", "", "", "", "", w.star ? "1" : "0", today, ""].joined(separator: ","))
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n")
    }
}
