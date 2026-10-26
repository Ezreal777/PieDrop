import AppKit
import Carbon.HIToolbox

/// 快捷键录制面板：打开后直接按键录入（需含 ⌃/⌥/⌘），Esc 或点击外部取消
final class HotkeyRecorderPanel: NSPanel {
    static let shared = HotkeyRecorderPanel()
    private var monitor: Any?
    private var clickMonitor: Any?
    private var onChange: ((UInt32, UInt32) -> Void)?
    private var onCancelled: (() -> Void)?
    private let promptLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "需包含 ⌃ / ⌥ / ⌘ 至少一个 · Esc 取消")

    private init() {
        let size = NSSize(width: 320, height: 96)
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        appearance = NSAppearance(named: .aqua)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.white.cgColor
        root.layer?.cornerRadius = 14
        root.layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        root.layer?.borderWidth = 0.5

        promptLabel.font = .systemFont(ofSize: 13, weight: .medium)
        promptLabel.textColor = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        promptLabel.alignment = .center
        promptLabel.frame = NSRect(x: 16, y: 52, width: size.width - 32, height: 18)
        root.addSubview(promptLabel)

        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = NSColor(srgbRed: 0.53, green: 0.53, blue: 0.55, alpha: 1)
        hintLabel.alignment = .center
        hintLabel.frame = NSRect(x: 16, y: 28, width: size.width - 32, height: 15)
        root.addSubview(hintLabel)

        contentView = root
    }

    required init?(coder: NSCoder) { fatalError() }

    override var canBecomeKey: Bool { true }

    func present(current: String,
                 onChange: @escaping (UInt32, UInt32) -> Void,
                 onCancelled: @escaping () -> Void) {
        cleanMonitors()
        self.onChange = onChange
        self.onCancelled = onCancelled
        promptLabel.stringValue = "按下新的快捷键…（当前 \(current)）"
        hintLabel.stringValue = "需包含 ⌃ / ⌥ / ⌘ 至少一个 · Esc 取消"

        let (mouse, screen) = Cursor.location()
        let vf = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        var origin = NSPoint(x: mouse.x - frame.width / 2, y: mouse.y + 60)
        origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - frame.width - 8)
        origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - frame.height - 8)
        setFrameOrigin(origin)
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] e in
            guard let self = self else { return e }
            if e.type == .flagsChanged {
                let mods = Self.carbon(e.modifierFlags)
                self.promptLabel.stringValue = mods == 0 ? "按下新的快捷键…" : HotkeyText.modSymbols(mods) + " …"
                return nil
            }
            if e.keyCode == UInt32(kVK_Escape) { self.cancel(); return nil }
            let mods = Self.carbon(e.modifierFlags)
            guard mods & UInt32(controlKey | optionKey | cmdKey) != 0 else {
                self.hintLabel.stringValue = "需包含 ⌃ / ⌥ / ⌘ 至少一个，请重按"
                return nil
            }
            self.finish(UInt32(e.keyCode), mods)
            return nil
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.cancel()
        }
    }

    private func finish(_ code: UInt32, _ mods: UInt32) {
        cleanMonitors()
        orderOut(nil)
        let cb = onChange
        onChange = nil
        onCancelled = nil
        NSLog("hotkey recorded: code=\(code) mods=\(mods)")
        cb?(code, mods)
    }

    private func cancel() {
        cleanMonitors()
        orderOut(nil)
        let cb = onCancelled
        onChange = nil
        onCancelled = nil
        cb?()
    }

    private func cleanMonitors() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    private static func carbon(_ f: NSEvent.ModifierFlags) -> UInt32 {
        var c: UInt32 = 0
        if f.contains(.control) { c |= UInt32(controlKey) }
        if f.contains(.option) { c |= UInt32(optionKey) }
        if f.contains(.shift) { c |= UInt32(shiftKey) }
        if f.contains(.command) { c |= UInt32(cmdKey) }
        return c
    }
}
