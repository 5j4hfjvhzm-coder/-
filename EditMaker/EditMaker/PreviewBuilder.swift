import AVFoundation
import CoreGraphics

/// After Effects 없이 앱 안에서 바로 보는 미리보기.
/// 컷·음악·줌 움직임만 재현하고, 자막은 플레이어 위에 따로 그려요. (진짜 결과는 CapCut/AE에서 확인)
enum PreviewBuilder {
    static func make(plan: EditPlan) async -> AVPlayerItem? {
        let comp = AVMutableComposition()
        guard let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
        let W = CGFloat(plan.width), H = CGFloat(plan.height)
        let ts: CMTimeScale = 600
        func t(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: ts) }

        struct Src { let track: AVAssetTrack; let size: CGSize; let pref: CGAffineTransform }
        var cache: [String: Src] = [:]

        for seg in plan.segments {
            let at = t(seg.start)
            let len = t(seg.length)
            let url = URL(fileURLWithPath: seg.clip)
            if MediaAnalyzer.imageExts.contains(url.pathExtension.lowercased()) {
                vTrack.insertEmptyTimeRange(CMTimeRange(start: at, duration: len))
                continue
            }
            if cache[seg.clip] == nil {
                let asset = AVURLAsset(url: url)
                if let tr = try? await asset.loadTracks(withMediaType: .video).first,
                   let info = try? await tr.load(.naturalSize, .preferredTransform) {
                    cache[seg.clip] = Src(track: tr, size: info.0, pref: info.1)
                }
            }
            guard let src = cache[seg.clip] else {
                vTrack.insertEmptyTimeRange(CMTimeRange(start: at, duration: len))
                continue
            }
            let srcRange = CMTimeRange(start: t(seg.clipIn), duration: t(seg.length * seg.speed))
            do {
                try vTrack.insertTimeRange(srcRange, of: src.track, at: at)
                if abs(seg.speed - 1) > 0.001 {
                    vTrack.scaleTimeRange(CMTimeRange(start: at, duration: srcRange.duration), toDuration: len)
                }
            } catch {
                vTrack.insertEmptyTimeRange(CMTimeRange(start: at, duration: len))
                continue
            }

            // 화면 꽉 채우기 + 줌 움직임
            let r = CGRect(origin: .zero, size: src.size).applying(src.pref)
            let ow = abs(r.width), oh = abs(r.height)
            let cover = max(W / max(ow, 1), H / max(oh, 1))
            func tf(_ k: Double, dx: Double = 0) -> CGAffineTransform {
                let s = cover * CGFloat(k)
                let fix = src.pref.concatenating(CGAffineTransform(translationX: -r.minX, y: -r.minY))
                return fix
                    .concatenating(CGAffineTransform(scaleX: s, y: s))
                    .concatenating(CGAffineTransform(translationX: (W - ow * s) / 2 + CGFloat(dx) * W / 2, y: (H - oh * s) / 2))
            }
            let endK = 1 + seg.push
            switch seg.transition {
            case "zoom_punch", "radial_blur":
                let k0 = seg.transition == "zoom_punch" ? 1.22 : 1.35
                let p = min(0.22, seg.length * 0.6)
                layer.setTransformRamp(fromStart: tf(k0), toEnd: tf(1.02), timeRange: CMTimeRange(start: at, duration: t(p)))
                layer.setTransformRamp(fromStart: tf(1.02), toEnd: tf(endK), timeRange: CMTimeRange(start: at + t(p), duration: t(seg.length - p)))
            case "whip":
                let p = min(0.25, seg.length * 0.5)
                layer.setTransformRamp(fromStart: tf(1, dx: 0.7), toEnd: tf(1), timeRange: CMTimeRange(start: at, duration: t(p)))
                layer.setTransformRamp(fromStart: tf(1), toEnd: tf(endK), timeRange: CMTimeRange(start: at + t(p), duration: t(seg.length - p)))
            default:
                layer.setTransformRamp(fromStart: tf(1), toEnd: tf(endK), timeRange: CMTimeRange(start: at, duration: len))
            }
            if seg.transition == "blur_in" || seg.transition == "flash" {
                layer.setOpacityRamp(fromStartOpacity: 0.25, toEndOpacity: 1, timeRange: CMTimeRange(start: at, duration: t(min(0.2, seg.length * 0.5))))
            } else {
                layer.setOpacity(1, at: at)
            }
        }

        // 음악
        if let m = plan.music,
           let aSrc = try? await AVURLAsset(url: URL(fileURLWithPath: m.path)).loadTracks(withMediaType: .audio).first,
           let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? aTrack.insertTimeRange(CMTimeRange(start: t(m.offset), duration: t(plan.duration)), of: aSrc, at: .zero)
        }

        guard comp.duration > .zero else { return nil }
        let instr = AVMutableVideoCompositionInstruction()
        instr.timeRange = CMTimeRange(start: .zero, duration: comp.duration)
        instr.layerInstructions = [layer]
        let vc = AVMutableVideoComposition()
        vc.renderSize = CGSize(width: W, height: H)
        vc.frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(plan.fps.rounded(), 1)))
        vc.instructions = [instr]

        let item = AVPlayerItem(asset: comp)
        item.videoComposition = vc
        return item
    }
}
