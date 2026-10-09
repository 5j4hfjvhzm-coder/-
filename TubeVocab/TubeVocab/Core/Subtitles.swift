import Foundation

/// 자막 파싱·문장 합치기·영/한 정렬. 시간 단위는 모두 ms.

protocol Timed {
    var start: Int { get }
    var end: Int { get }
}

struct Cue: Equatable, Timed {
    var start: Int
    var end: Int
    var text: String
}

struct BiCue: Equatable, Hashable, Timed {
    var start: Int
    var end: Int
    var en: String
    var ko: String
}

// MARK: - 유튜브 json3

struct Json3: Decodable {
    var events: [Json3Event]?
}

struct Json3Event: Decodable {
    var tStartMs: Int?
    var dDurationMs: Int?
    var segs: [Json3Seg]?
    var aAppend: Int?
}

struct Json3Seg: Decodable {
    var utf8: String?
    var tOffsetMs: Int?
}

struct TimedWord: Equatable {
    var t: Int
    var text: String
}

func cleanSubtitleText(_ s: String) -> String {
    var t = s.replacingRegex("<[^>]+>", with: "")
    t = t.replacingRegex("\\{\\\\[^}]*\\}", with: "")
    t = t.replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
    t = t.replacingRegex("\\s+", with: " ")
    return t.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func stableSorted<T>(_ items: [T], by key: (T) -> Int) -> [T] {
    items.enumerated().sorted { (key($0.element), $0.offset) < (key($1.element), $1.offset) }.map(\.element)
}

/// 겹치는 시간 구간을 다음 자막 시작에서 잘라준다 (자동생성/롤링 자막용).
func trimOverlaps(_ cues: [Cue]) -> [Cue] {
    let sorted = stableSorted(cues) { $0.start }
    return sorted.enumerated().map { i, c in
        var c = c
        if i + 1 < sorted.count {
            let next = sorted[i + 1]
            if next.start < c.end && next.start > c.start { c.end = next.start }
        }
        return c
    }
}

/// 일반(수동) json3 트랙 → 줄 단위 자막
func json3ToCues(_ json: Json3) -> [Cue] {
    var cues: [Cue] = []
    for ev in json.events ?? [] {
        guard let segs = ev.segs, (ev.aAppend ?? 0) == 0 else { continue }
        let text = cleanSubtitleText(segs.map { $0.utf8 ?? "" }.joined())
        if text.isEmpty { continue }
        let start = ev.tStartMs ?? 0
        cues.append(Cue(start: start, end: start + (ev.dDurationMs ?? 2000), text: text))
    }
    return trimOverlaps(dedupeAdjacent(cues))
}

private func dedupeAdjacent(_ cues: [Cue]) -> [Cue] {
    var out: [Cue] = []
    for c in cues {
        if let prev = out.last, prev.text == c.text, c.start - prev.end < 500 {
            out[out.count - 1].end = max(prev.end, c.end)
        } else {
            out.append(c)
        }
    }
    return out
}

/// 자동생성(asr) json3 트랙 → 단어별 시간
func json3ToWords(_ json: Json3) -> [TimedWord] {
    var out: [TimedWord] = []
    for ev in json.events ?? [] {
        guard let segs = ev.segs, (ev.aAppend ?? 0) == 0 else { continue }
        let base = ev.tStartMs ?? 0
        for seg in segs {
            for piece in (seg.utf8 ?? "").split(whereSeparator: { $0.isWhitespace }) {
                let text = cleanSubtitleText(String(piece))
                if text.isEmpty { continue }
                out.append(TimedWord(t: base + (seg.tOffsetMs ?? 0), text: text))
            }
        }
    }
    return stableSorted(out) { $0.t }
}

struct SentenceOptions {
    /// 이만큼 쉬면 문장을 끊는다
    var pauseMs = 700
    /// 쉼으로 끊으려면 최소 이만큼 단어가 있어야 함
    var minWords = 4
    /// 무조건 끊는 길이
    var maxWords = 18
}

private let sentenceEnd = "[.?!…][\"')\\]]*$"

/// 단어 시간 목록을 문장 단위 자막으로 합친다. 구두점이 있으면 구두점, 없으면 쉼/길이로 끊는다.
func wordsToSentences(_ ws: [TimedWord], options o: SentenceOptions = SentenceOptions()) -> [Cue] {
    var cues: [Cue] = []
    var cur: [TimedWord] = []
    func flush(_ endHint: Int) {
        guard let first = cur.first, let last = cur.last else { return }
        let end = max(last.t + 300, min(endHint, last.t + 1500))
        cues.append(Cue(start: first.t, end: end, text: cur.map(\.text).joined(separator: " ")))
        cur = []
    }
    for (i, w) in ws.enumerated() {
        let next: TimedWord? = i + 1 < ws.count ? ws[i + 1] : nil
        cur.append(w)
        let gap = next.map { $0.t - w.t } ?? Int.max
        let isLast = next == nil
        let endsSentence = w.text.matchesRegex(sentenceEnd)
        let tooLong = cur.count >= o.maxWords
        let longPause = gap >= o.pauseMs && cur.count >= o.minWords
        if isLast || endsSentence || tooLong || longPause {
            flush(next?.t ?? (w.t + 1500))
        }
    }
    return cues
}

/// 줄 단위 자막을 문장 단위로 합친다 (구두점 없이 끝나는 줄은 다음 줄과 붙임).
func mergeLinesToSentences(_ cues: [Cue], maxChars: Int = 160, maxGapMs: Int = 1500) -> [Cue] {
    var out: [Cue] = []
    for c in cues {
        if let prev = out.last,
           !prev.text.matchesRegex(sentenceEnd),
           c.start - prev.end <= maxGapMs,
           prev.text.count + c.text.count + 1 <= maxChars {
            out[out.count - 1].text = "\(prev.text) \(c.text)"
            out[out.count - 1].end = max(prev.end, c.end)
        } else {
            out.append(c)
        }
    }
    return out
}

private func overlap(_ a: Cue, _ b: Cue) -> Int {
    max(0, min(a.end, b.end) - max(a.start, b.start))
}

/// 영어 자막(기준) 각각에 한국어 자막을 시간 겹침으로 붙인다.
/// 한국어 자막 하나는 가장 많이 겹치는 영어 자막 하나에만 들어간다.
/// 겹치는 게 없으면 1초 안쪽으로 떨어진 가장 가까운 영어 자막에 붙인다.
func alignBilingual(_ en: [Cue], _ ko: [Cue], nearMs: Int = 1000) -> [BiCue] {
    if en.isEmpty {
        return ko.map { BiCue(start: $0.start, end: $0.end, en: "", ko: $0.text) }
    }
    var buckets = Array(repeating: [String](), count: en.count)
    var lo = 0
    for k in ko {
        while lo < en.count - 1 && en[lo].end <= k.start { lo += 1 }
        var best = -1
        var bestOv = 0
        var i = max(0, lo - 1)
        while i < en.count && en[i].start < k.end {
            let ov = overlap(en[i], k)
            if ov > bestOv {
                bestOv = ov
                best = i
            }
            i += 1
        }
        if best < 0 {
            var bestDist = Int.max
            for j in max(0, lo - 2)..<min(en.count, lo + 3) {
                let d = max(en[j].start - k.end, k.start - en[j].end, 0)
                if d < bestDist {
                    bestDist = d
                    best = j
                }
            }
            if bestDist > nearMs { best = -1 }
        }
        if best >= 0, buckets[best].last != k.text {
            buckets[best].append(k.text)
        }
    }
    return en.enumerated().map { i, c in
        BiCue(start: c.start, end: c.end, en: c.text, ko: buckets[i].joined(separator: " "))
    }
}

/// 현재 시간에 해당하는 자막 인덱스. 자막 사이 빈 구간에서는 직전 자막을 유지.
func findCueIndex<T: Timed>(_ cues: [T], _ t: Int) -> Int {
    var lo = 0
    var hi = cues.count - 1
    var ans = -1
    while lo <= hi {
        let mid = (lo + hi) / 2
        if cues[mid].start <= t {
            ans = mid
            lo = mid + 1
        } else {
            hi = mid - 1
        }
    }
    return ans
}

// MARK: - SRT / VTT

private let timePattern =
    "(?:(\\d+):)?(\\d{1,2}):(\\d{2})[.,](\\d{1,3})\\s*-->\\s*(?:(\\d+):)?(\\d{1,2}):(\\d{2})[.,](\\d{1,3})"

private func toMs(_ h: String?, _ m: String, _ s: String, _ ms: String) -> Int {
    let hours: Int = Int(h ?? "0") ?? 0
    let minutes: Int = Int(m) ?? 0
    let seconds: Int = Int(s) ?? 0
    let millis: Int = Int(ms.padding(toLength: 3, withPad: "0", startingAt: 0)) ?? 0
    let totalSeconds: Int = hours * 3600 + minutes * 60 + seconds
    return totalSeconds * 1000 + millis
}

func parseSrtVtt(_ raw: String) -> [Cue] {
    guard let re = RegexCache.cached(timePattern) else { return [] }
    var text = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
    let blocks = text.replacingRegex("\\n\\s*\\n", with: "\u{1}").components(separatedBy: "\u{1}")
    var cues: [Cue] = []
    for block in blocks {
        let lines = block.components(separatedBy: "\n")
        var found: (Int, NSTextCheckingResult)?
        for (i, line) in lines.enumerated() {
            if let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                found = (i, m)
                break
            }
        }
        guard let hit = found else { continue }
        let (ti, m) = hit
        let line = lines[ti]
        func g(_ i: Int) -> String? {
            let r = m.range(at: i)
            guard r.location != NSNotFound, let rr = Range(r, in: line) else { return nil }
            return String(line[rr])
        }
        let start = toMs(g(1), g(2) ?? "0", g(3) ?? "0", g(4) ?? "0")
        let end = toMs(g(5), g(6) ?? "0", g(7) ?? "0", g(8) ?? "0")
        let body = lines[(ti + 1)...].map(cleanSubtitleText).filter { !$0.isEmpty }
        if body.isEmpty { continue }
        cues.append(Cue(start: start, end: end, text: body.joined(separator: "\n")))
    }
    return stableSorted(cues) { $0.start }
}

private let hangulSyllables: ClosedRange<UInt32> = 0xAC00...0xD7A3
private let hangulJamo: ClosedRange<UInt32> = 0x3131...0x318E

func containsHangul(_ s: String) -> Bool {
    s.unicodeScalars.contains { scalar in
        let v: UInt32 = scalar.value
        return hangulSyllables.contains(v) || hangulJamo.contains(v)
    }
}

/// 한 파일에 영/한이 같이 들어있는 경우까지 처리: 줄마다 한글 여부로 나눈다.
func splitBilingual(_ cues: [Cue]) -> (en: [Cue], ko: [Cue]) {
    var en: [Cue] = []
    var ko: [Cue] = []
    for c in cues {
        let lines = c.text.components(separatedBy: "\n")
        let k = lines.filter(containsHangul).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let e = lines.filter { !containsHangul($0) }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if !e.isEmpty { en.append(Cue(start: c.start, end: c.end, text: e)) }
        if !k.isEmpty { ko.append(Cue(start: c.start, end: c.end, text: k)) }
    }
    return (en, ko)
}

func formatTime(_ ms: Int) -> String {
    let s = max(0, ms / 1000)
    let m = s / 60
    let h = m / 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m % 60, s % 60)
        : String(format: "%d:%02d", m, s % 60)
}
