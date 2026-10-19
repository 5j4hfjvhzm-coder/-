import SwiftUI
import UIKit

// MARK: - 색상 (시스템 키보드와 비슷하게, 라이트/다크 대응)

enum KB {
    static let key = dyn(0xFFFFFF, 0x6B6B6B)
    static let keyPressed = dyn(0xD1D4DA, 0x8E8E8E)
    static let special = dyn(0xACB1BB, 0x464646)
    static let specialPressed = dyn(0xFFFFFF, 0x6B6B6B)
    static let ink = dyn(0x000000, 0xFFFFFF)
    static let sub = dyn(0x6B6F78, 0xAAAAAA)
    static let shadow = dyn(0x898A8D, 0x1E1E1E)
    static let panel = dyn(0xF4F4F7, 0x2B2B2B)
    static let field = dyn(0xFFFFFF, 0x3A3A3C)
    static let accent = Color(UIColor(red: 0x6A / 255, green: 0x4F / 255, blue: 0xD8 / 255, alpha: 1))

    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { t in
            let v = t.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255,
                           green: CGFloat((v >> 8) & 0xFF) / 255,
                           blue: CGFloat(v & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

// MARK: - 루트

struct KeyboardRootView: View {
    let model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            if model.dictOpen {
                DictionaryPanel(model: model)
            } else {
                TopBar(model: model)
            }
            KeysView(model: model)
                .frame(height: KeyboardModel.keysHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.white.opacity(0.001)) // 빈 곳 터치가 뒤로 새지 않게
    }
}

// MARK: - 상단 바 (사전 버튼)

struct TopBar: View {
    let model: KeyboardModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.openDictionary()
            } label: {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(KB.accent)
                    .frame(width: 44, height: 34)
                    .background(KB.key.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .accessibilityLabel("사전")

            if !model.currentWord.isEmpty {
                Button {
                    model.openDictionary(prefill: model.currentWord)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12, weight: .bold))
                        Text("“\(model.currentWord)” 뜻 보기")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(KB.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(KB.key.opacity(0.6), in: Capsule())
                }
            }

            Spacer(minLength: 0)

            Text(model.lang == .ko ? "한" : "EN")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KB.sub)
                .padding(.trailing, 6)
        }
        .padding(.horizontal, 6)
        .frame(height: KeyboardModel.barHeight)
    }
}

// MARK: - 자판

struct KeysView: View {
    let model: KeyboardModel

    static let koRows: [[String]] = [
        ["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅛ", "ㅕ", "ㅑ", "ㅐ", "ㅔ"],
        ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"],
        ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"],
    ]
    static let enRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]
    static let numRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "₩", "&", "@", "\""],
        [".", ",", "?", "!", "'"],
    ]
    static let symRows: [[String]] = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "$", "£", "¥", "•"],
        [".", ",", "?", "!", "'"],
    ]

    private var rows: [[String]] {
        switch model.page {
        case .letters: model.lang == .ko ? Self.koRows : Self.enRows
        case .numbers: Self.numRows
        case .symbols: Self.symRows
        }
    }

    private let gap: CGFloat = 6
    private let side: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let unit = (geo.size.width - side * 2 - gap * 9) / 10
            let rowH = (geo.size.height - 8 - 3 * 11) / 4
            VStack(spacing: 11) {
                letterRow(rows[0], unit: unit, height: rowH)
                letterRow(rows[1], unit: unit, height: rowH)
                thirdRow(unit: unit, height: rowH, width: geo.size.width)
                bottomRow(unit: unit, height: rowH, width: geo.size.width)
            }
            .padding(.horizontal, side)
            .padding(.top, 2)
        }
    }

    private func letterRow(_ keys: [String], unit: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: gap) {
            ForEach(keys, id: \.self) { k in
                charKey(k, width: unit, height: height)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func charKey(_ k: String, width: CGFloat, height: CGFloat) -> some View {
        let title = model.page == .letters ? model.letterTitle(k) : k
        return KeyCap(width: width, height: height, special: false) {
            model.tapLetter(k)
        } label: {
            Text(title)
                .font(.system(size: model.page == .letters && model.lang == .ko ? 22 : 23))
                .foregroundStyle(KB.ink)
        }
    }

    private func thirdRow(unit: CGFloat, height: CGFloat, width: CGFloat) -> some View {
        let keys = rows[2]
        let sideW = unit * 1.35
        let inner = width - side * 2 - sideW * 2 - gap * 2
        let keyW = model.page == .letters ? unit : (inner - gap * CGFloat(keys.count - 1)) / CGFloat(keys.count)
        return HStack(spacing: gap) {
            leftModifier(width: sideW, height: height)
            Spacer(minLength: 0)
            HStack(spacing: gap) {
                ForEach(keys, id: \.self) { k in charKey(k, width: keyW, height: height) }
            }
            Spacer(minLength: 0)
            KeyCap(width: sideW, height: height, special: true, repeats: true) {
                model.tapBackspace()
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 19))
                    .foregroundStyle(KB.ink)
            }
            .accessibilityLabel("지우기")
        }
    }

    @ViewBuilder
    private func leftModifier(width: CGFloat, height: CGFloat) -> some View {
        switch model.page {
        case .letters:
            KeyCap(width: width, height: height, special: !(model.shift || model.capsLock)) {
                model.tapShift()
            } label: {
                Image(systemName: model.capsLock ? "capslock.fill" : (model.shift ? "shift.fill" : "shift"))
                    .font(.system(size: 19))
                    .foregroundStyle(KB.ink)
            }
            .accessibilityLabel("시프트")
        case .numbers:
            KeyCap(width: width, height: height, special: true) { model.setPage(.symbols) } label: {
                Text("#+=").font(.system(size: 16)).foregroundStyle(KB.ink)
            }
        case .symbols:
            KeyCap(width: width, height: height, special: true) { model.setPage(.numbers) } label: {
                Text("123").font(.system(size: 16)).foregroundStyle(KB.ink)
            }
        }
    }

    private func bottomRow(unit: CGFloat, height: CGFloat, width: CGFloat) -> some View {
        let small = unit * 1.25
        let ret = unit * 2.1
        let count = model.needsGlobe ? 3 : 2
        let space = width - side * 2 - small * CGFloat(count) - ret - gap * CGFloat(count + 1)
        return HStack(spacing: gap) {
            KeyCap(width: small, height: height, special: true) {
                model.setPage(model.page == .letters ? .numbers : .letters)
            } label: {
                Text(model.page == .letters ? "123" : (model.lang == .ko ? "가나다" : "ABC"))
                    .font(.system(size: model.page == .letters ? 16 : 14))
                    .foregroundStyle(KB.ink)
            }

            if model.needsGlobe {
                KeyCap(width: small, height: height, special: true) {
                    model.nextKeyboard()
                } label: {
                    Image(systemName: "globe").font(.system(size: 18)).foregroundStyle(KB.ink)
                }
                .accessibilityLabel("다음 키보드")
            }

            KeyCap(width: small, height: height, special: true) {
                model.toggleLang()
            } label: {
                HStack(spacing: 1) {
                    Text("한").foregroundStyle(model.lang == .ko ? KB.ink : KB.sub)
                    Text("/").foregroundStyle(KB.sub)
                    Text("영").foregroundStyle(model.lang == .en ? KB.ink : KB.sub)
                }
                .font(.system(size: 15, weight: .semibold))
            }
            .accessibilityLabel("한영 전환")

            KeyCap(width: max(space, unit * 2), height: height, special: false) {
                model.tapSpace()
            } label: {
                Text(model.lang == .ko ? "스페이스" : "space")
                    .font(.system(size: 15))
                    .foregroundStyle(KB.ink)
            }

            KeyCap(width: ret, height: height, special: !model.dictOpen, tint: model.dictOpen ? KB.accent : nil) {
                model.tapReturn()
            } label: {
                if model.dictOpen {
                    Text("검색").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                } else {
                    Text(model.returnLabel).font(.system(size: 16)).foregroundStyle(KB.ink)
                }
            }
        }
    }
}

// MARK: - 키 하나

struct KeyCap<Label: View>: View {
    var width: CGFloat
    var height: CGFloat
    var special: Bool
    var repeats = false
    var tint: Color?
    var action: () -> Void
    var label: () -> Label

    @State private var pressed = false
    @State private var repeatTask: Task<Void, Never>?

    init(width: CGFloat, height: CGFloat, special: Bool, repeats: Bool = false, tint: Color? = nil,
         action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.width = width
        self.height = height
        self.special = special
        self.repeats = repeats
        self.tint = tint
        self.action = action
        self.label = label
    }

    var body: some View {
        label()
            .frame(width: max(width, 1), height: max(height, 1))
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fill)
                    .shadow(color: KB.shadow, radius: 0, x: 0, y: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        pressed = true
                        UIDevice.current.playInputClick()
                        if repeats {
                            action()
                            repeatTask = Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(450))
                                while !Task.isCancelled {
                                    action()
                                    try? await Task.sleep(for: .milliseconds(80))
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                        repeatTask?.cancel()
                        repeatTask = nil
                        if !repeats { action() }
                    }
            )
            .accessibilityAddTraits(.isButton)
    }

    private var fill: Color {
        if let tint { return pressed ? tint.opacity(0.75) : tint }
        if special { return pressed ? KB.specialPressed : KB.special }
        return pressed ? KB.keyPressed : KB.key
    }
}
