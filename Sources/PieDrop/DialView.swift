import AppKit

// MARK: - 圆盘（面板左侧：彩色扇区 + CLI 名；中心留空小圆点）

final class DiskDialView: NSView {
    static let dialR: CGFloat = 80           // 圆盘半径（面板左侧即为该圆）
    var onHover: ((CliSession?) -> Void)?
    var onDeliver: ((Int) -> Void)?

    private let sessions: [CliSession]
    private let r1: CGFloat = 70
    private let r0: CGFloat = 34
    private let centerR: CGFloat = 24
    private let gapWidth: CGFloat = 4      // 扇区间恒定缝宽
    private var hoveredIndex: Int? { didSet { updateHover() } }
    private var sectorContainers: [CALayer] = []
    private var pathLayers: [CAShapeLayer] = []
    private var tracking: NSTrackingArea?

    init(frame: NSRect, sessions: [CliSession]) {
        self.sessions = sessions
        super.init(frame: frame)
        wantsLayer = true
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private var scale: CGFloat { NSScreen.main?.backingScaleFactor ?? 2 }
    private func circle(_ r: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: Self.dialR - r, y: Self.dialR - r, width: r * 2, height: r * 2), transform: nil)
    }
    private func polar(_ r: CGFloat, _ deg: Double) -> NSPoint {
        let rad = deg * .pi / 180
        return NSPoint(x: Self.dialR + CGFloat(r) * CGFloat(cos(rad)), y: Self.dialR + CGFloat(r) * CGFloat(sin(rad)))
    }
    /// 恒定缝宽扇区：缝隙两侧为平行线（各向缝中线缩进 gapWidth/2），消除内窄外宽的楔形
    private func sectorPath(_ b0: Double, _ b1: Double, _ ri: CGFloat, _ ro: CGFloat) -> CGPath {
        let half = Double(gapWidth / 2)
        let edge = { (r: CGFloat) -> Double in asin(min(1, half / Double(r))) * 180 / .pi }
        let a0o = b0 + edge(ro), a0i = b0 + edge(ri)
        let a1o = b1 - edge(ro), a1i = b1 - edge(ri)
        let p = CGMutablePath()
        let rad = { (deg: Double) -> CGFloat in CGFloat(deg * .pi / 180) }
        p.move(to: polar(ro, a0o))
        p.addArc(center: CGPoint(x: Self.dialR, y: Self.dialR), radius: ro, startAngle: rad(a0o), endAngle: rad(a1o), clockwise: false)
        p.addLine(to: polar(ri, a1i))
        p.addArc(center: CGPoint(x: Self.dialR, y: Self.dialR), radius: ri, startAngle: rad(a1i), endAngle: rad(a0i), clockwise: true)
        p.closeSubpath()
        return p
    }

    /// 单会话整环（两圆 even-odd 挖洞），无缝
    private func annulusPath() -> CGPath {
        let p = CGMutablePath()
        p.addPath(circle(r1))
        p.addPath(circle(r0))
        return p
    }

    private func build() {
        guard let root = layer else { return }

        // 极浅的圆形底衬，圈出圆盘区域（须留在玻璃圆 r=80 之内）
        let halo = CAShapeLayer()
        halo.path = circle(r1 + 6)
        halo.fillColor = NSColor.black.withAlphaComponent(0.035).cgColor
        halo.zPosition = 0
        root.addSublayer(halo)

        let n = sessions.count
        if n == 0 {
            buildCenter()
            return
        }
        let span = 360.0 / Double(n)
        for i in 0..<n {
            let s = sessions[i]
            let a0 = -90.0 + Double(i) * span
            let a1 = a0 + span
            let mid = a0 + span / 2
            let fillColor = Palette.fill(for: s.cliName)
            let textColor = Palette.text(for: s.cliName)

            let container = CALayer()
            container.frame = bounds
            container.zPosition = 1
            container.shadowColor = NSColor.black.cgColor
            container.shadowOffset = CGSize(width: 0, height: -2)
            container.shadowRadius = 4
            container.shadowOpacity = 0

            let shape = CAShapeLayer()
            shape.path = n == 1 ? annulusPath() : sectorPath(a0, a1, r0, r1)
            shape.fillRule = .evenOdd
            shape.fillColor = fillColor.withAlphaComponent(0.13).cgColor
            shape.lineWidth = 0
            shape.contentsScale = scale
            container.addSublayer(shape)
            pathLayers.append(shape)

            // 扇区标签：CLI 名
            let lp = polar((r0 + r1) / 2, mid)
            let nameAttr = NSAttributedString(string: s.label, attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: textColor,
            ])
            let nameLayer = CATextLayer()
            nameLayer.string = nameAttr
            nameLayer.contentsScale = scale
            let ns = nameAttr.size()
            nameLayer.frame = CGRect(x: lp.x - ns.width / 2 - 3, y: lp.y - ns.height / 2 - 3,
                                     width: ns.width + 6, height: ns.height + 6)
            container.addSublayer(nameLayer)

            container.shadowPath = shape.path
            root.addSublayer(container)
            sectorContainers.append(container)
        }

        buildCenter()
    }

    /// 中心留空：素圆 + 一颗小灰点（不放字）
    private func buildCenter() {
        guard let root = layer else { return }
        let center = CAShapeLayer()
        center.path = circle(centerR)
        center.fillColor = NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1).cgColor  // #F5F5F7
        center.strokeColor = NSColor.black.withAlphaComponent(0.07).cgColor
        center.lineWidth = 1
        center.contentsScale = scale
        center.zPosition = 20
        root.addSublayer(center)

        let dot = CAShapeLayer()
        dot.path = CGPath(ellipseIn: CGRect(x: Self.dialR - 2.5, y: Self.dialR - 2.5, width: 5, height: 5), transform: nil)
        dot.fillColor = NSColor(srgbRed: 0.78, green: 0.78, blue: 0.80, alpha: 1).cgColor
        dot.contentsScale = scale
        dot.zPosition = 21
        root.addSublayer(dot)
    }

    // MARK: hover

    private func sectorIndex(at p: NSPoint) -> Int? {
        let dx = p.x - Self.dialR
        let dy = p.y - Self.dialR
        let dist = (dx * dx + dy * dy).squareRoot()
        guard dist >= r0 - 2, dist <= r1 + 2 else { return nil }
        let n = sessions.count
        guard n > 0 else { return nil }
        if n == 1 { return 0 }
        var ang = atan2(Double(dy), Double(dx)) * 180 / .pi
        if ang < 0 { ang += 360 }
        let step = 360.0 / Double(n)
        // 缝隙恒宽：命中判定按当前半径换算缝的半角
        let halfGap = asin(min(1, Double(gapWidth / 2) / dist)) * 180 / .pi
        for i in 0..<n {
            let b0 = -90.0 + Double(i) * step
            var s = b0 + halfGap
            var e = b0 + step - halfGap
            while s < 0 { s += 360 }
            while e < 0 { e += 360 }
            if s <= e {
                if ang >= s && ang <= e { return i }
            } else {
                if ang >= s || ang <= e { return i }   // 跨 0° 的扇区
            }
        }
        return nil
    }

    private func updateHover() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.16)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        for (i, container) in sectorContainers.enumerated() {
            let on = (i == hoveredIndex)
            container.transform = on ? CATransform3DMakeScale(1.05, 1.05, 1) : CATransform3DIdentity
            container.zPosition = on ? 10 : 1
            container.shadowOpacity = on ? 0.10 : 0
            if i < pathLayers.count {
                let fillColor = Palette.fill(for: sessions[i].cliName)
                pathLayers[i].fillColor = fillColor.withAlphaComponent(on ? 0.26 : 0.13).cgColor
            }
        }
        CATransaction.commit()
        onHover?(hoveredIndex.map { sessions[$0] })
    }

    // MARK: 事件

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// 只在圆内响应，圆外透给宿主（点击面板外区域关闭）
    override func hitTest(_ p: NSPoint) -> NSView? {
        let dx = p.x - Self.dialR
        let dy = p.y - Self.dialR
        guard dx * dx + dy * dy <= Self.dialR * Self.dialR else { return nil }
        return super.hitTest(p)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
                               owner: self, userInfo: nil)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let idx = sectorIndex(at: p)
        hoveredIndex = idx
        if let i = idx { NSLog("dial hover \(i) → \(sessions[i].cliName)@\(sessions[i].tty)") }
    }

    override func mouseExited(with event: NSEvent) {
        if hoveredIndex != nil { hoveredIndex = nil }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let i = sectorIndex(at: p) { onDeliver?(i) }
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}
