import AppKit

// MARK: - 调色板（白底苹果风：浅色填充 + 深色文字）

enum Palette {
    static func fill(for name: String) -> NSColor {
        switch name {
        case "qodercli": return NSColor(srgbRed: 0.545, green: 0.486, blue: 0.965, alpha: 1)  // 紫
        case "claude":   return NSColor(srgbRed: 0.878, green: 0.541, blue: 0.373, alpha: 1)  // 陶土橙
        case "codex":    return NSColor(srgbRed: 0.247, green: 0.769, blue: 0.706, alpha: 1)  // 青
        case "gemini":   return NSColor(srgbRed: 0.361, green: 0.659, blue: 1.000, alpha: 1)  // 蓝
        case "aider":    return NSColor(srgbRed: 0.949, green: 0.757, blue: 0.302, alpha: 1)  // 金
        case "zsh", "bash", "fish":
                         return NSColor(srgbRed: 0.557, green: 0.557, blue: 0.576, alpha: 1)  // 系统灰
        default:         return NSColor(srgbRed: 0.306, green: 0.804, blue: 0.769, alpha: 1)
        }
    }

    /// 白底上可读的深色文字版
    static func text(for name: String) -> NSColor {
        switch name {
        case "qodercli": return NSColor(srgbRed: 0.380, green: 0.337, blue: 0.788, alpha: 1)
        case "claude":   return NSColor(srgbRed: 0.690, green: 0.373, blue: 0.188, alpha: 1)
        case "codex":    return NSColor(srgbRed: 0.122, green: 0.557, blue: 0.510, alpha: 1)
        case "gemini":   return NSColor(srgbRed: 0.208, green: 0.447, blue: 0.839, alpha: 1)
        case "aider":    return NSColor(srgbRed: 0.722, green: 0.541, blue: 0.078, alpha: 1)
        case "zsh", "bash", "fish":
                         return NSColor(srgbRed: 0.400, green: 0.400, blue: 0.420, alpha: 1)
        default:         return NSColor(srgbRed: 0.122, green: 0.557, blue: 0.510, alpha: 1)
        }
    }
}

// MARK: - 鼠标定位（CGEvent 全局坐标 → AppKit 坐标，并定位所在屏幕）

enum Cursor {
    static func location() -> (point: NSPoint, screen: NSScreen?) {
        if let event = CGEvent(source: nil) {
            let cg = event.location
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            let p = NSPoint(x: CGFloat(cg.x), y: primaryHeight - CGFloat(cg.y))
            let screen = NSScreen.screens.first { $0.frame.contains(p) } ?? NSScreen.main
            return (p, screen)
        }
        let m = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(m) } ?? NSScreen.main
        return (m, screen)
    }
}

// MARK: - 轻提示（白底）

enum Toast {
    static func show(_ text: String) {
        let size = NSSize(width: 320, height: 44)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.appearance = NSAppearance(named: .aqua)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let v = NSView(frame: NSRect(origin: .zero, size: size))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.white.cgColor
        v.layer?.cornerRadius = 11
        v.layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        v.layer?.borderWidth = 0.5

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        label.alignment = .center
        label.frame = NSRect(x: 10, y: 13, width: size.width - 20, height: 18)
        v.addSubview(label)
        panel.contentView = v

        let (mouse, screen) = Cursor.location()
        let vf = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y + 30)
        origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
        origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { panel.orderOut(nil) }
    }
}

// MARK: - 会话文案（终端窗口标题 → 任务缩略）

enum SessionText {
    /// 终端窗口标题带 CLI 的任务缩略（形如 "demo — ◇ 询问用户姓名 | Ready — node ◂ qodercli — 120×30"）
    static func thumbnail(_ s: CliSession) -> String {
        var wt = s.windowTitle.trimmingCharacters(in: .whitespaces)
        if let range = wt.range(of: " — ") { wt = String(wt[range.upperBound...]) }
        if let range = wt.range(of: " — node") { wt = String(wt[..<range.lowerBound]) }
        return wt.trimmingCharacters(in: .whitespaces)
    }

    static func truncate(_ s: String, _ max: Int) -> String {
        s.count > max ? s.prefix(max - 1) + "…" : s
    }
}
