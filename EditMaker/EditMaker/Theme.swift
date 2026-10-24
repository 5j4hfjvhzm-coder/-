import AVFoundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum Theme {
    static let pink = Color(red: 1, green: 0.24, blue: 0.68)
    static let purple = Color(red: 0.55, green: 0.33, blue: 1)
    static let blue = Color(red: 0.2, green: 0.6, blue: 1)
    static let cyan = Color(red: 0.35, green: 0.95, blue: 1)
    static let bg = Color(red: 0.035, green: 0.025, blue: 0.07)
    static let card = Color.white.opacity(0.05)
    static let stroke = Color.white.opacity(0.1)
    static let dim = Color.white.opacity(0.55)

    static let neon = LinearGradient(colors: [pink, purple, blue], startPoint: .leading, endPoint: .trailing)
    static let neonDiagonal = LinearGradient(colors: [pink, purple, blue], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func hex(_ s: String) -> Color {
        guard let c = HexColor.hex(s) else { return .white }
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    static func transitionColor(_ id: String) -> Color {
        switch id {
        case "zoom_punch": return pink
        case "flash": return .white
        case "blur_in": return purple
        case "radial_blur": return cyan
        case "whip": return blue
        default: return Color.white.opacity(0.35)
        }
    }
}

/// 천천히 움직이는 네온 오로라 배경
struct AuroraBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    Theme.bg
                    blob(Theme.pink, size: w * 0.55)
                        .offset(x: cos(t * 0.13) * w * 0.25 - w * 0.2, y: sin(t * 0.17) * h * 0.2 - h * 0.25)
                    blob(Theme.purple, size: w * 0.6)
                        .offset(x: sin(t * 0.11) * w * 0.3 + w * 0.25, y: cos(t * 0.09) * h * 0.25)
                    blob(Theme.blue, size: w * 0.45)
                        .offset(x: cos(t * 0.07 + 2) * w * 0.3, y: sin(t * 0.12 + 1) * h * 0.3 + h * 0.3)
                }
                .frame(width: w, height: h)
            }
        }
        .overlay(Noise().opacity(0.05))
        .ignoresSafeArea()
    }

    private func blob(_ c: Color, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [c.opacity(0.45), c.opacity(0)], center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .blur(radius: 60)
    }
}

/// 은은한 필름 그레인
struct Noise: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 42)
            for _ in 0..<1800 {
                let x = rng.unit() * size.width, y = rng.unit() * size.height
                ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(rng.unit())))
            }
        }
        .allowsHitTesting(false)
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    var glow: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Material.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(glow ? AnyShapeStyle(Theme.neonDiagonal) : AnyShapeStyle(Theme.stroke), lineWidth: glow ? 1.5 : 1)
            )
            .shadow(color: glow ? Theme.pink.opacity(0.25) : .clear, radius: 24)
    }
}

struct NeonButtonStyle: ButtonStyle {
    var big = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: big ? 17 : 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, big ? 28 : 16)
            .padding(.vertical, big ? 14 : 9)
            .background(Theme.neon.opacity(enabled ? 1 : 0.3), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: Theme.pink.opacity(enabled ? (configuration.isPressed ? 0.2 : 0.55) : 0), radius: big ? 22 : 12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil
    var symbol: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let symbol {
                Image(systemName: symbol).foregroundStyle(Theme.neon)
            }
            Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
            if let subtitle {
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
            Spacer()
        }
    }
}

struct Chip: View {
    var text: String
    var symbol: String? = nil
    var tint: Color = .white

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
            Text(text).font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 1))
    }
}

/// 파일을 끌어다 놓는 영역
struct DropZone<Content: View>: View {
    var onDrop: ([URL]) -> Void
    @ViewBuilder var content: Content
    @State private var targeted = false

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(targeted ? Theme.pink.opacity(0.12) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(targeted ? AnyShapeStyle(Theme.neon) : AnyShapeStyle(Color.white.opacity(0.18)),
                                  style: StrokeStyle(lineWidth: targeted ? 2 : 1.2, dash: targeted ? [] : [7, 6]))
            )
            .scaleEffect(targeted ? 1.01 : 1)
            .animation(.spring(response: 0.3), value: targeted)
            .dropDestination(for: URL.self) { urls, _ in
                onDrop(urls)
                return true
            } isTargeted: { targeted = $0 }
    }
}

/// 영상·이미지 썸네일 (비동기 로드 + 캐시)
struct Thumbnail: View {
    var url: URL
    var time: Double = 0.5
    @State private var image: NSImage? = nil

    var body: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.06))
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .clipped()
        .task(id: url) { image = await ThumbCache.shared.image(for: url, at: time) }
    }
}

actor ThumbCache {
    static let shared = ThumbCache()
    private var cache: [String: NSImage] = [:]

    func image(for url: URL, at time: Double) async -> NSImage? {
        let key = url.path + "#\(time)"
        if let c = cache[key] { return c }
        var img: NSImage?
        if MediaAnalyzer.imageExts.contains(url.pathExtension.lowercased()) {
            img = NSImage(contentsOf: url)
        } else {
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 360, height: 360)
            let dur = (try? await asset.load(.duration).seconds) ?? 1
            let t = CMTime(seconds: min(max(time, 0), max(dur - 0.05, 0)), preferredTimescale: 600)
            if let cg = try? await gen.image(at: t).image {
                img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            }
        }
        if let img { cache[key] = img }
        return img
    }
}

enum Panels {
    @MainActor
    static func open(types: [String]? = nil, multiple: Bool, title: String) -> [URL] {
        let p = NSOpenPanel()
        p.title = title
        p.allowsMultipleSelection = multiple
        p.canChooseDirectories = false
        p.canChooseFiles = true
        if let types { p.allowedContentTypes = types.compactMap { UTType(filenameExtension: $0) } }
        return p.runModal() == .OK ? p.urls : []
    }
}
