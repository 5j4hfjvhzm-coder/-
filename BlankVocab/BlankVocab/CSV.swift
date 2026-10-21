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

    /// 첫 줄의 열 이름을 보고 단어 목록으로 바꿔요.
    /// "단어(W)"처럼 괄호 안의 약자(W, M, G, P, POS, E, DER, SIM, S, A, D, B, C, I)로도 열을 찾아요.
    static func words(from rows: [[String]]) -> [Word] {
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
        func col(_ ns: [String], code: String, _ def: Int = -1) -> Int {
            if let i = names.firstIndex(where: { ns.contains($0) }) { return i }
            if let i = codes.firstIndex(of: code) { return i }
            return def
        }
        let iw = col(["단어", "word"], code: "w", 0)
        let im = col(["의미", "뜻", "meaning"], code: "m", 1)
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
        let ic = col(["날짜", "date"], code: "c")
        let ii = col(["이미지", "image"], code: "i")

        func get(_ r: [String], _ i: Int) -> String {
            i >= 0 && i < r.count ? r[i].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        }
        return rows.dropFirst().compactMap { r in
            let w = get(r, iw)
            guard !w.isEmpty else { return nil }
            let mark = get(r, ib)
            var word = Word(w: w, m: get(r, im), e: get(r, ie), p: get(r, ip), star: !mark.isEmpty && mark != "0")
            word.g = get(r, ig)
            word.pron = get(r, ipr)
            word.der = get(r, ider)
            word.sim = get(r, isim)
            word.syn = get(r, isyn)
            word.ant = get(r, iant)
            word.d = get(r, id)
            word.c = get(r, ic)
            word.img = get(r, ii)
            return word
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
            lines.append([q(w.w), q(w.m), q(w.g), q(w.pron), q(w.p), q(w.e), q(w.der), q(w.sim), q(w.syn), q(w.ant), q(w.d),
                          w.star ? "1" : "0", q(w.c.isEmpty ? today : w.c), q(w.img)].joined(separator: ","))
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n")
    }
}
