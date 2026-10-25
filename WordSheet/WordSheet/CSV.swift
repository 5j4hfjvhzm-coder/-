import Foundation

enum CSV {
    /// 따옴표("...")와 셀 안 줄바꿈을 지원하는 CSV 파서
    static func parse(_ input: String) -> [[String]] {
        var text = input
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        var rows: [[String]] = []
        var row: [String] = []
        var cell = ""
        var quoted = false
        let chars = Array(text.unicodeScalars)
        var i = 0
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
        return rows.filter { $0.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    /// 빈칸 단어장 CSV 형식을 읽어요. 첫 줄 열 이름으로 열을 찾아요:
    /// 단어(W), 의미(M), 성별(G), 발음(P), 품사(POS), 예문(E), 파생어(DER), 유의어(SIM), 동의어(S), 반의어(A), 설명(D), 마크(B), 날짜(C), 이미지(I)
    /// 열 이름이 없는 파일이면 첫 열을 단어, 둘째 열을 뜻으로 읽어요.
    static func entries(from rows: [[String]]) -> [Entry] {
        guard let header = rows.first else { return [] }
        var names: [String] = []
        var codes: [String] = []
        for h in header {
            var s = h
            var code = ""
            if let r = s.range(of: #"\(.*\)"#, options: .regularExpression) {
                code = String(s[r]).trimmingCharacters(in: CharacterSet(charactersIn: "() ")).lowercased()
                s.removeSubrange(r)
            }
            names.append(s.trimmingCharacters(in: .whitespaces).lowercased())
            codes.append(code)
        }
        func col(_ ns: [String], code: String) -> Int? {
            if let i = names.firstIndex(where: { ns.contains($0) }) { return i }
            if let i = codes.firstIndex(of: code) { return i }
            return nil
        }
        let fw = col(["단어", "word"], code: "w")
        let fm = col(["의미", "뜻", "meaning"], code: "m")
        let hasHeader = fw != nil || fm != nil
        let iw = fw ?? 0
        let im = fm ?? 1
        let ig = col(["성별", "gender"], code: "g")
        let ipr = col(["발음", "pronunciation"], code: "p")
        let ip = col(["품사", "pos"], code: "pos")
        let ie = col(["예문", "example"], code: "e")
        let ider = col(["파생어", "derivative", "derivatives"], code: "der")
        let isim = col(["유의어", "similar"], code: "sim")
        let isyn = col(["동의어", "synonym", "synonyms"], code: "s")
        let iant = col(["반의어", "antonym", "antonyms"], code: "a")
        let id = col(["설명", "description", "note"], code: "d")
        let ib = col(["마크", "mark", "b"], code: "b")

        func get(_ r: [String], _ i: Int?) -> String {
            guard let i, i >= 0, i < r.count else { return "" }
            return r[i].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let body = hasHeader ? Array(rows.dropFirst()) : rows
        return body.compactMap { r in
            let w = get(r, iw)
            guard !w.isEmpty else { return nil }
            var e = Entry()
            e.w = w
            e.m = get(r, im)
            e.g = get(r, ig)
            e.pron = get(r, ipr)
            e.pos = get(r, ip)
            e.e = get(r, ie)
            e.der = get(r, ider)
            e.sim = get(r, isim)
            e.syn = get(r, isyn)
            e.ant = get(r, iant)
            e.d = get(r, id)
            let mark = get(r, ib)
            // 예전 CSV에서 마크(★)한 단어는 노란 형광펜으로 가져와요
            if !mark.isEmpty && mark != "0" { e.marker = .yellow }
            return e
        }
    }

    /// UTF-8 → UTF-16(BOM 있을 때) → EUC-KR(엑셀 한글 CSV) 순서로 읽어요.
    static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let s = String(data: data, encoding: .utf16) {
            return s
        }
        if let s = String(data: data, encoding: .utf8) { return s }
        let euckr = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue))
        return String(data: data, encoding: String.Encoding(rawValue: euckr))
    }
}
