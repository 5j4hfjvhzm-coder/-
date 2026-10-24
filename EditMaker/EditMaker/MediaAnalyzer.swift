import AVFoundation
import CoreGraphics
import ImageIO

/// 영상·이미지를 읽고, 레퍼런스 영상의 컷 타이밍·비트·색감을 분석해요. (AVFoundation만 써서 따로 설치할 게 없어요)
enum MediaAnalyzer {
    enum AnalyzeError: LocalizedError {
        case unreadable(String)
        var errorDescription: String? {
            switch self {
            case .unreadable(let name): return "\(name) 파일을 읽을 수 없어요. 영상(mp4, mov)이나 이미지인지 확인해 주세요."
            }
        }
    }

    static let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "tif", "tiff", "gif", "webp", "psd", "bmp"]
    static let audioExts: Set<String> = ["mp3", "m4a", "wav", "aac", "aif", "aiff", "flac"]

    // MARK: - 파일 하나 읽기

    static func loadItem(_ url: URL) async throws -> MediaItem {
        let ext = url.pathExtension.lowercased()
        if imageExts.contains(ext) {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
                throw AnalyzeError.unreadable(url.lastPathComponent)
            }
            let w = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 1080
            let h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 1920
            return MediaItem(url: url, duration: 0, width: w, height: h, isStill: true, hasAudio: false)
        }

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let vtracks = try await asset.loadTracks(withMediaType: .video)
        let atracks = try await asset.loadTracks(withMediaType: .audio)
        guard (!vtracks.isEmpty || !atracks.isEmpty), duration.isFinite, duration > 0 else {
            throw AnalyzeError.unreadable(url.lastPathComponent)
        }
        var w = 0.0, h = 0.0
        if let v = vtracks.first {
            let (size, transform) = try await v.load(.naturalSize, .preferredTransform)
            let r = CGRect(origin: .zero, size: size).applying(transform)
            w = abs(r.width)
            h = abs(r.height)
        }
        return MediaItem(url: url, duration: duration, width: w, height: h, isStill: false, hasAudio: !atracks.isEmpty)
    }

    // MARK: - 레퍼런스 분석

    /// 레퍼런스 영상을 분석하고, AI가 볼 대표 장면 몇 장도 함께 돌려줘요.
    static func analyzeReference(_ url: URL, progress: @escaping @Sendable (String) -> Void) async throws -> (ReferenceAnalysis, [CGImage]) {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw AnalyzeError.unreadable(url.lastPathComponent) }
        let item = try await loadItem(url)

        // 1) 컷 & 색감: 작은 프레임을 초당 8장씩 훑어요.
        progress("장면 전환 찾는 중…")
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 48, height: 48)
        let tol = CMTime(seconds: 0.04, preferredTimescale: 600)
        gen.requestedTimeToleranceBefore = tol
        gen.requestedTimeToleranceAfter = tol

        let step = 1.0 / 8.0
        let scanEnd = min(duration, 180)
        var times: [Double] = []
        var t = 0.0
        while t < scanEnd { times.append(t); t += step }

        var prev: [Float]? = nil
        var diffs: [Double] = []
        var diffTimes: [Double] = []
        var satSum = 0.0, briSum = 0.0, count = 0.0
        var hueX = 0.0, hueY = 0.0
        for (i, time) in times.enumerated() {
            if i % 40 == 0 { progress("장면 전환 찾는 중… \(Int(Double(i) / Double(max(times.count, 1)) * 100))%") }
            guard let img = try? await gen.image(at: CMTime(seconds: time, preferredTimescale: 600)).image,
                  let px = pixels(img, side: 24) else { continue }
            if let p = prev {
                var d: Float = 0
                for k in 0..<px.count { d += abs(px[k] - p[k]) }
                diffs.append(Double(d) / Double(px.count))
                diffTimes.append(time - step / 2)
            }
            prev = px
            // 색 통계
            var k = 0
            while k + 2 < px.count {
                let (h, s, b) = hsb(Double(px[k]), Double(px[k + 1]), Double(px[k + 2]))
                satSum += s; briSum += b; count += 1
                let wgt = s * b
                hueX += cos(h * 2 * .pi) * wgt
                hueY += sin(h * 2 * .pi) * wgt
                k += 3
            }
        }
        let cuts = detectCuts(diffs: diffs, times: diffTimes)

        // 2) 비트
        progress("음악 비트 찾는 중…")
        let samples = (try? await loadAudioMono(asset, sampleRate: 22050, maxSeconds: scanEnd)) ?? []
        var (beats, bpm, strength) = detectBeats(samples: samples, sampleRate: 22050)
        if beats.isEmpty {
            bpm = 120
            beats = stride(from: 0.0, to: duration, by: 0.5).map { $0 }
            strength = beats.map { _ in 0.5 }
        }

        // 3) AI가 볼 대표 장면 4장
        progress("대표 장면 고르는 중…")
        let big = AVAssetImageGenerator(asset: asset)
        big.appliesPreferredTrackTransform = true
        big.maximumSize = CGSize(width: 512, height: 512)
        var keyframes: [CGImage] = []
        for f in [0.15, 0.4, 0.65, 0.9] {
            if let img = try? await big.image(at: CMTime(seconds: duration * f, preferredTimescale: 600)).image {
                keyframes.append(img)
            }
        }

        var hue = atan2(hueY, hueX) / (2 * .pi)
        if hue < 0 { hue += 1 }
        let cps = Double(cuts.count) / max(duration, 1)
        let energy = (min(cps / 2.5, 1) * 0.65 + min(max((bpm - 80) / 80, 0), 1) * 0.35).clamped(0, 1)

        let analysis = ReferenceAnalysis(
            duration: duration,
            width: item.width > 0 ? item.width : 1080,
            height: item.height > 0 ? item.height : 1920,
            cuts: cuts,
            beats: beats,
            bpm: bpm,
            beatStrength: strength,
            hue: hue,
            saturation: count > 0 ? satSum / count : 0.4,
            brightness: count > 0 ? briSum / count : 0.5,
            energy: energy
        )
        return (analysis, keyframes)
    }

    // MARK: - 픽셀

    /// side×side 로 줄인 RGB(0~1) 배열
    static func pixels(_ image: CGImage, side: Int) -> [Float]? {
        var raw = [UInt8](repeating: 0, count: side * side * 4)
        let ok: Bool = raw.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            ctx.interpolationQuality = .low
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard ok else { return nil }
        var out = [Float]()
        out.reserveCapacity(side * side * 3)
        for i in 0..<(side * side) {
            out.append(Float(raw[i * 4]) / 255)
            out.append(Float(raw[i * 4 + 1]) / 255)
            out.append(Float(raw[i * 4 + 2]) / 255)
        }
        return out
    }

    static func hsb(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var h = 0.0
        if d > 0 {
            if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, mx > 0 ? d / mx : 0, mx)
    }

    // MARK: - 컷 찾기

    static func detectCuts(diffs: [Double], times: [Double]) -> [Double] {
        guard diffs.count > 2 else { return [] }
        let sorted = diffs.sorted()
        let median = sorted[sorted.count / 2]
        let threshold = max(0.11, median * 3.2)
        var cuts: [Double] = []
        for i in diffs.indices {
            let d = diffs[i]
            guard d > threshold else { continue }
            let left = i > 0 ? diffs[i - 1] : 0
            let right = i + 1 < diffs.count ? diffs[i + 1] : 0
            guard d >= left && d >= right else { continue }
            if let last = cuts.last, times[i] - last < 0.2 { continue }
            cuts.append((times[i] * 100).rounded() / 100)
        }
        return cuts
    }

    // MARK: - 오디오 & 비트

    static func loadAudioMono(_ asset: AVAsset, sampleRate: Double, maxSeconds: Double) async throws -> [Float] {
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        guard reader.canAdd(output) else { return [] }
        reader.add(output)
        guard reader.startReading() else { return [] }
        let limit = Int(maxSeconds * sampleRate)
        var samples: [Float] = []
        samples.reserveCapacity(limit)
        while samples.count < limit, let sb = output.copyNextSampleBuffer() {
            guard let bb = CMSampleBufferGetDataBuffer(sb) else { continue }
            let len = CMBlockBufferGetDataLength(bb)
            var chunk = [Float](repeating: 0, count: len / MemoryLayout<Float>.size)
            chunk.withUnsafeMutableBytes { ptr in
                _ = CMBlockBufferCopyDataBytes(bb, atOffset: 0, dataLength: ptr.count, destination: ptr.baseAddress!)
            }
            samples.append(contentsOf: chunk)
        }
        reader.cancelReading()
        return samples
    }

    /// 저음(킥) 위주로 소리가 세지는 순간을 찾아 BPM과 박자 위치를 추정해요.
    static func detectBeats(samples: [Float], sampleRate: Double) -> (beats: [Double], bpm: Double, strength: [Double]) {
        let hop = 512, win = 1024
        guard samples.count > win * 8 else { return ([], 0, []) }
        let envRate = sampleRate / Double(hop)

        // 저역 통과(약 150Hz) 신호
        var low = [Float](repeating: 0, count: samples.count)
        let a = Float(exp(-2 * Double.pi * 150 / sampleRate))
        var y: Float = 0
        for i in samples.indices { y = (1 - a) * samples[i] + a * y; low[i] = y }

        var fullE: [Double] = [], lowE: [Double] = []
        var i = 0
        while i + win <= samples.count {
            var e1: Float = 0, e2: Float = 0
            for k in i..<(i + win) { e1 += samples[k] * samples[k]; e2 += low[k] * low[k] }
            fullE.append(log(1 + 1000 * Double(e1) / Double(win)))
            lowE.append(log(1 + 1000 * Double(e2) / Double(win)))
            i += hop
        }
        var onset = [Double](repeating: 0, count: fullE.count)
        for k in 1..<fullE.count {
            onset[k] = 0.6 * max(0, lowE[k] - lowE[k - 1]) + 0.4 * max(0, fullE[k] - fullE[k - 1])
        }
        let mean = onset.reduce(0, +) / Double(onset.count)
        let centered = onset.map { $0 - mean }

        // 템포: 70~180 BPM 중 자기상관이 가장 큰 간격
        var bestLag = 0.0, bestScore = -Double.infinity
        let minLag = Int(60 * envRate / 180), maxLag = Int(60 * envRate / 70)
        for lag in max(minLag, 1)...max(maxLag, minLag + 1) {
            var s = 0.0
            for k in lag..<centered.count { s += centered[k] * centered[k - lag] }
            let bpm = 60 * envRate / Double(lag)
            let pref = exp(-0.5 * pow(log2(bpm / 120) / 0.9, 2)) // 120 근처를 조금 더 선호
            s *= pref
            if s > bestScore { bestScore = s; bestLag = Double(lag) }
        }
        guard bestLag > 0 else { return ([], 0, []) }

        // 위상: 그리드 위 onset 합이 가장 큰 시작점
        var bestPhase = 0, bestSum = -Double.infinity
        for p in 0..<Int(bestLag) {
            var s = 0.0
            var pos = Double(p)
            while Int(pos.rounded()) < onset.count { s += onset[Int(pos.rounded())]; pos += bestLag }
            if s > bestSum { bestSum = s; bestPhase = p }
        }
        var beats: [Double] = [], strength: [Double] = []
        var pos = Double(bestPhase)
        let peak = max(onset.max() ?? 1, 1e-6)
        while Int(pos.rounded()) < onset.count {
            let c = Int(pos.rounded())
            let lo = max(0, c - 2), hi = min(onset.count - 1, c + 2)
            let local = onset[lo...hi].max() ?? 0
            beats.append(((Double(c) / envRate) * 1000).rounded() / 1000)
            strength.append(min(local / peak * 1.5, 1))
            pos += bestLag
        }
        return (beats, 60 * envRate / bestLag, strength)
    }
}
