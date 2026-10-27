import AppKit

// MARK: - 圆盘（面板左侧：彩色扇区 + CLI 名；中心留空小圆点）

final class DiskDialView: NSView {
    static let dialR: CGFloat = 80           // 圆盘半径（面板左侧即为该圆）
    var onHover: ((CliSession?) -> Void)?
    var onDeliver: ((Int) -> Void)?
    /// 当前悬停的会话（草稿预取推送刷新右侧卡片用）
    var hoveredSession: CliSession? { hoveredIndex.map { sessions[$0] } }

    private let sessions: [CliSession]
    private let r1: CGFloat = 70
    private let r0: CGFloat = 34
    private let centerR: CGFloat = 24
    private let gapWidth: CGFloat = 4      // 扇区间恒定缝宽
    private var hoveredIndex: Int? { didSet { updateHover() } }
    private var sectorContainers: [CALayer] = []
    private var pathLayers: [CAShapeLayer] = []
    private var rotators: [CALayer] = []
    private var labelLayers: [CATextLayer] = []
    private var tracking: NSTrackingArea?
    /// 各会话输入框是否有未发送草稿（草稿预取完成后由面板写入）
    private var hasInput: [Bool] = []
    /// 各扇区角度跨度（按 hasInput 加权分配）
    private var spans: [Double] = []
    /// 有草稿的扇区角度权重（无草稿为 1.0）
    private static let hasInputWeight: Double = 1.6

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

        rebuildSectors()
        buildCenter()
    }

    /// 草稿预取完成后由面板调用：hasInput[i] = 会话 i 输入框是否有未发送内容。
    /// 稍等面板首帧渲染完成再启动动画，避免与弹出布局争抢造成掉帧。
    func updateHasInput(_ flags: [Bool]) {
        guard flags.count == sessions.count, flags != hasInput else { return }
        hasInput = flags
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.animateToWeightedLayout()
        }
    }

    /// 等分 → 加权角度的平滑过渡：扇区路径做隐式动画，标签沿弧线同步滑动
    /// （旋转层正向转 + 文字反向转，净旋转恒为 0，文字始终水平）。
    private func animateToWeightedLayout() {
        let n = sessions.count
        guard n > 1, pathLayers.count == n, labelLayers.count == n, rotators.count == n, sectorContainers.count == n else {
            rebuildSectors()   // 结构不完整时退化为重建
            return
        }
        let weights = hasInput.map { $0 ? Self.hasInputWeight : 1.0 }
        let total = weights.reduce(0, +)
        spans = weights.map { 360.0 * $0 / total }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.35)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        hoveredIndex = nil
        var start = -90.0
        for i in 0..<n {
            let b0 = start
            let b1 = start + spans[i]
            start = b1
            let newPath = sectorPath(b0, b1, r0, r1)
            pathLayers[i].path = newPath
            sectorContainers[i].shadowPath = newPath
            let rot = CGFloat(((b0 + b1) / 2) * .pi / 180)
            rotators[i].transform = CATransform3DMakeRotation(rot, 0, 0, 1)
            labelLayers[i].transform = CATransform3DMakeRotation(-rot, 0, 0, 1)
        }
        CATransaction.commit()
    }

    /// 依据当前 hasInput 重建全部扇区（角度加权；全有/全无时退化为等分）
    private func rebuildSectors() {
        guard let root = layer else { return }
        for c in sectorContainers { c.removeFromSuperlayer() }
        sectorContainers.removeAll()
        pathLayers.removeAll()
        rotators.removeAll()
        labelLayers.removeAll()
        hoveredIndex = nil

        let n = sessions.count
        guard n > 0 else { return }
        if hasInput.count != n { hasInput = Array(repeating: false, count: n) }
        let weights = hasInput.map { $0 ? Self.hasInputWeight : 1.0 }
        let total = weights.reduce(0, +)
        spans = weights.map { 360.0 * $0 / total }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setDisableActions(true)
        var start = -90.0
        for i in 0..<n {
            let s = sessions[i]
            let b0 = start
            let b1 = start + spans[i]
            let mid = (b0 + b1) / 2
            start = b1
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
            shape.path = n == 1 ? annulusPath() : sectorPath(b0, b1, r0, r1)
            shape.fillRule = .evenOdd
            shape.fillColor = fillColor.withAlphaComponent(0.13).cgColor
            shape.lineWidth = 0
            shape.contentsScale = scale
            container.addSublayer(shape)
            pathLayers.append(shape)

            // 扇区标签：挂在旋转层上（锚点=圆心），文字自身反向旋转保持水平。
            // 角度变化时对旋转层做动画，文字沿弧线运动、与扇区边界逐帧同步。
            let rotator = CALayer()
            rotator.bounds = CGRect(x: 0, y: 0, width: Self.dialR * 2, height: Self.dialR * 2)
            rotator.position = CGPoint(x: Self.dialR, y: Self.dialR)
            rotator.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            rotator.transform = CATransform3DMakeRotation(CGFloat(mid * .pi / 180), 0, 0, 1)
            container.addSublayer(rotator)
            rotators.append(rotator)

            let nameAttr = NSAttributedString(string: s.shortLabel, attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: textColor,
            ])
            let nameLayer = CATextLayer()
            nameLayer.string = nameAttr
            nameLayer.contentsScale = scale
            nameLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            let ns = nameAttr.size()
            nameLayer.bounds = CGRect(x: 0, y: 0, width: ns.width + 6, height: ns.height + 6)
            nameLayer.position = CGPoint(x: Self.dialR + (r0 + r1) / 2, y: Self.dialR)
            nameLayer.transform = CATransform3DMakeRotation(CGFloat(-mid * .pi / 180), 0, 0, 1)
            rotator.addSublayer(nameLayer)
            labelLayers.append(nameLayer)

            container.shadowPath = shape.path
            root.addSublayer(container)
            sectorContainers.append(container)
        }
        CATransaction.commit()
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
        // 缝隙恒宽：命中判定按当前半径换算缝的半角
        let halfGap = asin(min(1, Double(gapWidth / 2) / dist)) * 180 / .pi
        // 扇区按累积跨度匹配（支持变角度）；取模处理跨 0° 的扇区
        var start = -90.0
        for i in 0..<n {
            let span = i < spans.count ? spans[i] : 360.0 / Double(n)
            let inner = span - 2 * halfGap
            if inner > 0 {
                var rel = (ang - (start + halfGap)).truncatingRemainder(dividingBy: 360)
                if rel < 0 { rel += 360 }
                if rel <= inner { return i }
            }
            start += span
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
