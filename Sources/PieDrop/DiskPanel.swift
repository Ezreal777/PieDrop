import AppKit

// MARK: - 面板宿主（点击面板形状之外关闭）

final class PanelHostView: NSView {
    var onBackgroundClick: (() -> Void)?
    var keepRects: [NSRect] = []
    var circleHit: (center: NSPoint, radius: CGFloat)?

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let c = circleHit {
            let dx = p.x - c.center.x, dy = p.y - c.center.y
            if dx * dx + dy * dy <= c.radius * c.radius { super.mouseDown(with: event); return }
        }
        for r in keepRects where r.contains(p) { super.mouseDown(with: event); return }
        onBackgroundClick?()
    }
}

// MARK: - 面板（光环 = 磨砂「左圆右方」一体面板；菜单 = 毛玻璃卡片）

final class DiskPanel: NSPanel {
    enum Mode: String {
        case halo, menu
        static var stored: Mode {
            Mode(rawValue: UserDefaults.standard.string(forKey: "PieDrop.panelMode") ?? "") ?? .halo
        }
    }

    private let paths: [String]
    private let sessions: [CliSession]
    private var draftCache: [String: String?] = [:]
    private(set) var mode: Mode
    var anchor: NSPoint = .zero

    // 光环：内容面板 396×160（左圆右方），窗口四周留 haloPad 画自绘阴影；背景为磨砂玻璃
    static let haloPad: CGFloat = 24
    static let haloPanelSize = NSSize(width: 396, height: 160)
    static var haloSize: NSSize {
        NSSize(width: haloPanelSize.width + haloPad * 2, height: haloPanelSize.height + haloPad * 2)
    }
    /// 圆盘圆心在窗口坐标系中的位置
    static var haloDiskCenter: NSPoint {
        NSPoint(x: haloPad + haloPanelSize.height / 2, y: haloPad + haloPanelSize.height / 2)
    }

    init(paths: [String], sessions: [CliSession], mode: Mode) {
        self.paths = paths
        self.sessions = sessions
        self.mode = mode
        let size = Self.windowSize(for: mode, sessionCount: sessions.count)
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        appearance = NSAppearance(named: .aqua)
        isOpaque = false
        backgroundColor = .clear
        // 半透明面板统一自绘阴影（系统阴影在透明窗上有矩形灰影风险）
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        buildContent()
    }

    static func windowSize(for mode: Mode, sessionCount n: Int) -> NSSize {
        if mode == .halo { return haloSize }
        let menuH: CGFloat = 28 + CGFloat(n) * MenuRow.mainHeight + CGFloat(max(n - 1, 0)) * 2 + MenuRow.detailHeight + 14
        let cardH = max(menuH, 150)
        return NSSize(width: 300 + 80, height: cardH + 80)
    }

    /// 「左圆 + 右方块」一体轮廓：左边缘为完整半圆弧，右半融入矩形（面板本地坐标，左下原点）
    static func unionPath(width: CGFloat, height: CGFloat) -> CGPath {
        let R = height / 2
        let c = NSPoint(x: R, y: R)
        let rr: CGFloat = 10
        let p = CGMutablePath()
        // 从圆顶部沿左侧画到圆底部（经过左边缘）
        p.move(to: NSPoint(x: c.x, y: c.y + R))
        p.addArc(center: NSPoint(x: c.x, y: c.y), radius: R,
                 startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: false)
        // 底边 → 右下圆角 → 右边 → 右上圆角 → 回到圆顶
        p.addLine(to: NSPoint(x: width - rr, y: c.y - R))
        p.addArc(center: NSPoint(x: width - rr, y: c.y - R + rr), radius: rr,
                 startAngle: -.pi / 2, endAngle: 0, clockwise: false)
        p.addLine(to: NSPoint(x: width, y: c.y + R - rr))
        p.addArc(center: NSPoint(x: width - rr, y: c.y + R - rr), radius: rr,
                 startAngle: 0, endAngle: .pi / 2, clockwise: false)
        p.closeSubpath()
        return p
    }

    private func desiredFrame() -> NSRect {
        let size = Self.windowSize(for: mode, sessionCount: sessions.count)
        let vf = (NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main)?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        var origin: NSPoint
        if mode == .halo {
            // 圆盘圆心对准鼠标
            origin = NSPoint(x: anchor.x - Self.haloDiskCenter.x, y: anchor.y - Self.haloDiskCenter.y)
        } else {
            // 菜单卡片左上角贴鼠标下方
            origin = NSPoint(x: anchor.x - 40 + 6, y: anchor.y - 46 - (size.height - 80))
        }
        origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
        origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        return NSRect(origin: origin, size: size)
    }

    func refreshFrame() {
        setFrame(desiredFrame(), display: true)
    }

    private func buildContent() {
        let host = PanelHostView(frame: NSRect(origin: .zero, size: frame.size))
        host.autoresizingMask = [.width, .height]
        host.onBackgroundClick = { DiskPanelController.shared.dismiss() }

        if mode == .halo {
            let pad = Self.haloPad
            let ps = Self.haloPanelSize

            // 磨砂「左圆右方」玻璃底 + 自绘阴影
            let wrap = NSView(frame: NSRect(x: pad, y: pad, width: ps.width, height: ps.height))
            wrap.wantsLayer = true
            wrap.layer?.shadowColor = NSColor.black.cgColor
            wrap.layer?.shadowOpacity = 0.20
            wrap.layer?.shadowRadius = 18
            wrap.layer?.shadowOffset = CGSize(width: 0, height: -6)
            wrap.layer?.shadowPath = Self.unionPath(width: ps.width, height: ps.height)

            let vev = NSVisualEffectView(frame: wrap.bounds)
            vev.material = .popover
            vev.state = .active
            vev.wantsLayer = true
            let mask = CAShapeLayer()
            mask.path = Self.unionPath(width: ps.width, height: ps.height)
            vev.layer?.mask = mask
            wrap.addSubview(vev)

            let dial = DiskDialView(frame: NSRect(x: 0, y: 0, width: DiskDialView.dialR * 2, height: DiskDialView.dialR * 2),
                                    sessions: sessions)
            dial.onDeliver = { [weak self] idx in self?.deliver(idx) }
            vev.addSubview(dial)

            let divider = NSBox()
            divider.boxType = .separator
            divider.frame = NSRect(x: 172, y: 16, width: 1, height: ps.height - 32)
            vev.addSubview(divider)

            let card = PreviewCardView(frame: NSRect(x: 184, y: 0, width: ps.width - 184 - 12, height: ps.height))
            if sessions.isEmpty {
                card.showEmpty()
            } else {
                card.showNeutral()
                dial.onHover = { [weak self, weak card] session in
                    guard let self = self, let card = card, let session = session else { return }
                    card.update(session: session, draft: self.draft(for: session))
                }
            }
            vev.addSubview(card)

            host.addSubview(wrap)
            host.circleHit = (center: Self.haloDiskCenter, radius: DiskDialView.dialR + 2)
            host.keepRects = [NSRect(x: Self.haloDiskCenter.x, y: pad,
                                     width: ps.width - Self.haloDiskCenter.x + pad, height: ps.height)]
        } else {
            let cardH = frame.height - 80
            let wrap = NSView(frame: NSRect(x: 40, y: 40, width: 300, height: cardH))
            wrap.wantsLayer = true
            wrap.layer?.shadowColor = NSColor.black.cgColor
            wrap.layer?.shadowOpacity = 0.22
            wrap.layer?.shadowRadius = 24
            wrap.layer?.shadowOffset = CGSize(width: 0, height: -8)
            wrap.layer?.shadowPath = CGPath(roundedRect: wrap.bounds, cornerWidth: 16, cornerHeight: 16, transform: nil)

            let vev = NSVisualEffectView(frame: wrap.bounds)
            vev.material = .popover
            vev.state = .active
            vev.wantsLayer = true
            vev.layer?.cornerRadius = 16
            vev.layer?.masksToBounds = true
            wrap.addSubview(vev)

            let menu = MenuView(frame: NSRect(x: 0, y: 0, width: 300, height: cardH),
                                sessions: sessions,
                                draftProvider: { [weak self] s in self?.draft(for: s) ?? nil })
            menu.onPick = { [weak self] idx in self?.deliver(idx) }
            vev.addSubview(menu)

            host.addSubview(wrap)
            host.keepRects = [wrap.frame]
        }

        contentView = host
    }

    /// 草稿读取按会话缓存（每次弹出面板时刷新一次）
    private func draft(for s: CliSession) -> String? {
        let key = s.tty
        if let cached = draftCache[key] { return cached }
        let result = DraftReader.draft(kind: s.terminalKind, tty: s.tty)
        draftCache[key] = result
        return result
    }

    override var canBecomeKey: Bool { false }

    private func deliver(_ idx: Int) {
        guard idx < sessions.count else { return }
        let target = sessions[idx]
        NSLog("deliver[\(idx)] → \(target.cliName)@\(target.tty) pid=\(target.pid) paths=\(paths.count)")
        let text = paths.joined(separator: " ") + " "
        DiskPanelController.shared.dismiss()
        guard target.tty.hasPrefix("ttys") && target.pid > 0 else {
            Toast.show("演示模式：跳过真实注入")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Injector.inject(text, into: target)
        }
    }
}

// MARK: - 控制器（面板生命周期 + 全局点击/Esc 关闭）

final class DiskPanelController {
    static let shared = DiskPanelController()
    private var panel: DiskPanel?
    private var outsideMonitor: Any?
    private var escGlobalMonitor: Any?
    private var escLocalMonitor: Any?
    private(set) var isVisible = false

    func present(paths: [String], sessions: [CliSession], anchorOverride: NSPoint? = nil) {
        dismiss()
        let mode = DiskPanel.Mode.stored
        let p = DiskPanel(paths: paths, sessions: sessions, mode: mode)
        panel = p
        let (mouse, _) = Cursor.location()
        p.anchor = anchorOverride ?? mouse
        p.refreshFrame()
        NSLog("PieDrop present anchor=\(p.anchor) mode=\(mode.rawValue) frame=\(p.frame)")
        p.orderFrontRegardless()
        isVisible = true
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
        // Esc 关闭（面板为非激活窗口，需全局监听；不拦截事件本身）
        escGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53 { self?.dismiss() }
        }
        escLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53 { self?.dismiss() }
            return e
        }
    }

    func dismiss() {
        if let m = outsideMonitor { NSEvent.removeMonitor(m); outsideMonitor = nil }
        if let m = escGlobalMonitor { NSEvent.removeMonitor(m); escGlobalMonitor = nil }
        if let m = escLocalMonitor { NSEvent.removeMonitor(m); escLocalMonitor = nil }
        panel?.orderOut(nil)
        panel = nil
        isVisible = false
    }
}
