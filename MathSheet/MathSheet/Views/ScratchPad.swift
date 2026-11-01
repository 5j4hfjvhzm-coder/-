import PencilKit
import SwiftUI

/// 문제마다 붙는 필기 연습장 (Apple Pencil)
struct ScratchPad: View {
    @EnvironmentObject var store: Store
    let problemID: String

    @State private var drawing: PKDrawing
    @State private var version = 0          // 지우기·되돌리기로 바뀌면 캔버스에 다시 넣어요
    @State private var history: [PKDrawing] = []
    @State private var ink: Ink = .black
    @State private var erasing = false
    @State private var tall = false

    enum Ink: CaseIterable {
        case black, blue, red
        var ui: UIColor { self == .black ? .black : self == .blue ? .systemBlue : .systemRed }
        var color: Color { Color(uiColor: ui) }
    }

    init(problemID: String) {
        self.problemID = problemID
        _drawing = State(initialValue: DrawingStore.load(problemID))
    }

    private var tool: PKTool {
        erasing ? PKEraserTool(.vector) : PKInkingTool(.pen, color: ink.ui, width: 3)
    }

    var body: some View {
        VStack(spacing: 6) {
            toolbar
            ZStack {
                GridPaper()
                CanvasView(drawing: drawing, version: version, tool: tool,
                           fingerDraws: store.settings.fingerDrawing) { new in
                    guard new.dataRepresentation() != drawing.dataRepresentation() else { return }
                    history.append(drawing)
                    if history.count > 30 { history.removeFirst() }
                    drawing = new
                    DrawingStore.save(new, for: problemID)
                }
            }
            .frame(height: tall ? 440 : 220)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
        }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            Label("연습장", systemImage: "pencil.and.scribble")
                .font(.callout.bold())
                .foregroundStyle(.secondary)
            Spacer()
            ForEach(Ink.allCases, id: \.self) { i in
                Button { ink = i; erasing = false } label: {
                    Circle().fill(i.color)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.primary, lineWidth: !erasing && ink == i ? 2.5 : 0).padding(-4))
                }
                .accessibilityLabel(i == .black ? "검정 펜" : i == .blue ? "파란 펜" : "빨간 펜")
            }
            Button { erasing = true } label: {
                Image(systemName: erasing ? "eraser.fill" : "eraser")
            }
            .accessibilityLabel("지우개")
            Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(history.isEmpty)
                .accessibilityLabel("되돌리기")
            Button { clear() } label: { Image(systemName: "trash") }
                .disabled(drawing.strokes.isEmpty)
                .accessibilityLabel("모두 지우기")
            Button { store.settings.fingerDrawing.toggle() } label: {
                Image(systemName: store.settings.fingerDrawing ? "hand.draw.fill" : "hand.draw")
            }
            .accessibilityLabel(store.settings.fingerDrawing ? "손가락으로 쓰기 끄기" : "손가락으로도 쓰기")
            Button { withAnimation { tall.toggle() } } label: {
                Image(systemName: tall ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .accessibilityLabel(tall ? "연습장 작게" : "연습장 크게")
        }
        .font(.title3)
        .buttonStyle(.borderless)
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        drawing = last
        version += 1
        DrawingStore.save(last, for: problemID)
    }

    private func clear() {
        history.append(drawing)
        drawing = PKDrawing()
        version += 1
        DrawingStore.save(drawing, for: problemID)
    }
}

/// 모눈종이 배경 (다크 모드에서도 흰 종이)
struct GridPaper: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var p = Path()
            let step: CGFloat = 24
            var x: CGFloat = step
            while x < size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)); x += step }
            var y: CGFloat = step
            while y < size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)); y += step }
            ctx.stroke(p, with: .color(Color.blue.opacity(0.12)), lineWidth: 1)
        }
    }
}

/// PencilKit 캔버스
struct CanvasView: UIViewRepresentable {
    var drawing: PKDrawing
    var version: Int
    var tool: PKTool
    var fingerDraws: Bool
    var onChange: (PKDrawing) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> PKCanvasView {
        let v = ScratchCanvas()
        v.backgroundColor = .clear
        v.isOpaque = false
        v.isScrollEnabled = false
        v.overrideUserInterfaceStyle = .light   // 흰 종이 위에 검정 잉크 그대로
        v.drawingPolicy = fingerDraws ? .anyInput : .pencilOnly
        v.tool = tool
        context.coordinator.updating = true
        v.drawing = drawing
        context.coordinator.updating = false
        context.coordinator.version = version
        v.delegate = context.coordinator
        return v
    }

    func updateUIView(_ v: PKCanvasView, context: Context) {
        context.coordinator.onChange = onChange
        v.tool = tool
        v.drawingPolicy = fingerDraws ? .anyInput : .pencilOnly
        if context.coordinator.version != version {
            context.coordinator.version = version
            context.coordinator.updating = true
            v.drawing = drawing
            context.coordinator.updating = false
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onChange: (PKDrawing) -> Void
        var updating = false
        var version = 0

        init(onChange: @escaping (PKDrawing) -> Void) { self.onChange = onChange }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            if !updating { onChange(canvasView.drawing) }
        }
    }
}

/// 펜으로 쓰는 동안 바깥 화면이 같이 스크롤되지 않게 해요. (손가락으로는 그대로 스크롤)
final class ScratchCanvas: PKCanvasView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        var view = superview
        while let v = view {
            if let scroll = v as? UIScrollView {
                scroll.panGestureRecognizer.require(toFail: drawingGestureRecognizer)
                break
            }
            view = v.superview
        }
    }
}

/// 필기는 문제마다 따로 파일로 저장해요 (Documents/drawings/문제id.drawing)
enum DrawingStore {
    private static var dir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("drawings", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private static func url(_ id: String) -> URL { dir.appendingPathComponent("\(id).drawing") }

    static func exists(_ id: String) -> Bool { FileManager.default.fileExists(atPath: url(id).path) }

    static func load(_ id: String) -> PKDrawing {
        guard let data = try? Data(contentsOf: url(id)), let d = try? PKDrawing(data: data) else { return PKDrawing() }
        return d
    }

    static func save(_ drawing: PKDrawing, for id: String) {
        if drawing.strokes.isEmpty {
            try? FileManager.default.removeItem(at: url(id))
        } else {
            try? drawing.dataRepresentation().write(to: url(id), options: .atomic)
        }
    }

    static func removeAll() {
        try? FileManager.default.removeItem(at: dir)
    }
}
