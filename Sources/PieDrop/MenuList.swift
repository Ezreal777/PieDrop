import AppKit

// MARK: - 玻璃菜单（菜单 tab：单行 + hover 展开任务缩略/草稿）

final class MenuRow: NSView {
    static let mainHeight: CGFloat = 40
    static let detailHeight: CGFloat = 46

    let session: CliSession
    let index: Int
    var onSelect: (() -> Void)?

    private let dot = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let dirLabel = NSTextField(labelWithString: "")
    private let taskLabel = NSTextField(labelWithString: "")
    private let draftLabel = NSTextField(labelWithString: "")
    private var heightC: NSLayoutConstraint!
    private var hovered = false
    private(set) var expanded = false

    private static let dark = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    private static let textDark = NSColor(srgbRed: 0.25, green: 0.25, blue: 0.27, alpha: 1)
    private static let gray = NSColor(srgbRed: 0.53, green: 0.53, blue: 0.55, alpha: 1)

    init(session: CliSession, index: Int) {
        self.session = session
        self.index = index
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10

        dot.wantsLayer = true
        dot.layer?.backgroundColor = Palette.fill(for: session.cliName).cgColor
        dot.layer?.cornerRadius = 4.5
        dot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)

        nameLabel.stringValue = session.cliName
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = Self.dark
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        dirLabel.stringValue = session.cwdName
        dirLabel.font = .systemFont(ofSize: 11)
        dirLabel.textColor = Self.gray
        dirLabel.lineBreakMode = .byTruncatingTail
        dirLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dirLabel)

        let thumb = SessionText.thumbnail(session)
        taskLabel.stringValue = thumb.isEmpty ? "（无任务缩略）" : thumb
        taskLabel.font = .systemFont(ofSize: 11)
        taskLabel.textColor = Self.textDark
        taskLabel.lineBreakMode = .byTruncatingTail
        taskLabel.alphaValue = 0
        taskLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(taskLabel)

        draftLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        draftLabel.textColor = Self.dark
        draftLabel.lineBreakMode = .byTruncatingTail
        draftLabel.alphaValue = 0
        draftLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(draftLabel)

        // 子视图全部 layer-backed：展开/收起动画期间几何与透明度都走 Core Animation
        // （渲染进程合成），主线程只剩事件处理，动画不因主线程繁忙而掉帧
        for v: NSView in [dot, nameLabel, dirLabel, taskLabel, draftLabel] { v.wantsLayer = true }

        heightC = heightAnchor.constraint(equalToConstant: Self.mainHeight)
        NSLayoutConstraint.activate([
            heightC,
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            dot.widthAnchor.constraint(equalToConstant: 9),
            dot.heightAnchor.constraint(equalToConstant: 9),
            dot.centerYAnchor.constraint(equalTo: topAnchor, constant: Self.mainHeight / 2),
            nameLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
            dirLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 8),
            dirLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            dirLabel.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
            taskLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 31),
            taskLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            taskLabel.topAnchor.constraint(equalTo: topAnchor, constant: Self.mainHeight + 1),
            draftLabel.leadingAnchor.constraint(equalTo: taskLabel.leadingAnchor),
            draftLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            draftLabel.topAnchor.constraint(equalTo: taskLabel.bottomAnchor, constant: 4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 只改展开状态（高度约束/文字透明度）；布局与动画由 MenuView 合并到一次事务里统一做，
    /// 避免"塌缩一行"和"展开另一行"分成两个几何过渡
    func setExpanded(_ e: Bool) {
        guard expanded != e else { return }
        expanded = e
        heightC.constant = e ? Self.mainHeight + Self.detailHeight : Self.mainHeight
        taskLabel.alphaValue = e ? 1 : 0
        draftLabel.alphaValue = e ? 1 : 0
    }

    /// 草稿文字由外部缓存直读后写入（hover 时 / 预取推送），读取永不阻塞主线程
    func setDraftText(_ d: String?) {
        draftLabel.stringValue = (d?.isEmpty == false) ? "草稿 ▏\(d!) ▌" : "草稿 （输入框为空）"
    }

    /// hover 高亮由 MenuView 按坐标统一判定后调用
    func setHovered(_ on: Bool) {
        guard hovered != on else { return }
        hovered = on
        refreshTint()
    }

    private func refreshTint() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        layer?.backgroundColor = hovered
            ? Palette.fill(for: session.cliName).withAlphaComponent(0.14).cgColor
            : NSColor.clear.cgColor
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) { onSelect?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

final class MenuView: NSView {
    fileprivate static let isDemo = CommandLine.arguments.contains("--demo")
    var onPick: ((Int) -> Void)?
    /// 草稿来源（DiskPanel 的缓存直读版，绝不触发 AppleScript）
    private let draftProvider: (CliSession) -> String?
    private var rows: [MenuRow] = []
    private var topConstraints: [NSLayoutConstraint] = []
    private var headerLabel: NSTextField!
    private var hoveredRow: MenuRow?
    private var hoverTracking: NSTrackingArea?

    init(frame: NSRect, sessions: [CliSession], draftProvider: @escaping (CliSession) -> String?) {
        self.draftProvider = draftProvider
        super.init(frame: frame)

        let header = NSTextField(labelWithString: "追加路径到…")
        header.font = .systemFont(ofSize: 11)
        header.textColor = NSColor(srgbRed: 0.53, green: 0.53, blue: 0.55, alpha: 1)
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
        ])
        headerLabel = header

        var prev: NSView = header
        for (i, s) in sessions.enumerated() {
            let row = MenuRow(session: s, index: i)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.onSelect = { [weak self, weak row] in self?.onPick?(row?.index ?? i) }
            addSubview(row)
            let top = row.topAnchor.constraint(equalTo: prev.bottomAnchor, constant: 2)
            NSLayoutConstraint.activate([
                top,
                row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            ])
            topConstraints.append(top)
            rows.append(row)
            prev = row
        }

        if sessions.isEmpty {
            let empty = NSTextField(labelWithString: "未发现运行中的 CLI 会话")
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = NSColor(srgbRed: 0.53, green: 0.53, blue: 0.55, alpha: 1)
            empty.translatesAutoresizingMaskIntoConstraints = false
            addSubview(empty)
            NSLayoutConstraint.activate([
                empty.topAnchor.constraint(equalTo: prev.bottomAnchor, constant: 10),
                empty.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 草稿预取每读完一个会话即推送（缓存直读，无阻塞）：刷新对应行文字，
    /// 行未展开也先写入，展开时透明度动画自然带出
    func refreshDraft(for session: CliSession) {
        rows.first { $0.session.tty == session.tty }?.setDraftText(draftProvider(session))
    }

    /// 草稿预取完成后调用：有输入的行排前面（组内保持原顺序）
    func applyHasInput(_ flags: [Bool]) {
        guard flags.count == rows.count else { return }
        let withInput = zip(rows, flags).filter { $0.1 }.map { $0.0 }
        let without = zip(rows, flags).filter { !$0.1 }.map { $0.0 }
        let reordered = withInput + without
        guard reordered != rows else { return }
        relayout(reordered, animated: true)
    }

    /// 按新顺序重排行（重新串接纵向约束），展开态跟随对应的行
    private func relayout(_ newOrder: [MenuRow], animated: Bool) {
        rows = newOrder
        NSLayoutConstraint.deactivate(topConstraints)
        topConstraints.removeAll()
        var prev: NSView = headerLabel
        for r in rows {
            let top = r.topAnchor.constraint(equalTo: prev.bottomAnchor, constant: 2)
            top.isActive = true
            topConstraints.append(top)
            prev = r
        }
        for r in rows { r.setExpanded(r === hoveredRow) }
        guard animated else {
            layoutSubtreeIfNeeded()
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layoutSubtreeIfNeeded()
        })
        // 重排后按光标当前位置重判 hover（光标没动也可能有行滑过）
        if let loc = window?.mouseLocationOutsideOfEventStream {
            updateHoverForLocation(convert(loc, from: nil))
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 弹出时光标若已落在某行上，立即展开该行（无需等待鼠标移动事件）
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil else { return }
            if let loc = self.window?.mouseLocationOutsideOfEventStream {
                self.updateHoverForLocation(self.convert(loc, from: nil))
            }
        }
    }

    // MARK: hover（由 MenuView 按坐标统一判定，动画期间不依赖逐行 tracking 区）

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = hoverTracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds,
                               options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
                               owner: self, userInfo: nil)
        addTrackingArea(t)
        hoverTracking = t
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoverForLocation(convert(event.locationInWindow, from: nil), stepping: true)
    }

    override func mouseExited(with event: NSEvent) {
        setHoveredRow(nil)
    }

    /// 按目标布局的投影判定 hover 行（不依赖动画中的实时 frame）。两道保险：
    /// 1. 行间 2pt 缝隙用 ±3pt 容差盖住——否则滑过缝隙会判成"无行"而整体塌缩，
    ///    塌缩让下方行上移，光标原地就会"落"进更低的行，这正是跳行的来源；
    /// 2. 换行本身会改变布局（上一行塌缩、本行展开），所以对换行后的投影
    ///    反复求命中直到收敛，收敛的行才是光标真正对应的行；不收敛（边界震荡）时保持现状防闪烁。
    /// （internal：demo 自测钩子按坐标序列直接调用，绕过真实鼠标）
    func updateHoverForLocation(_ p: NSPoint, stepping: Bool = false) {
        var candidate = hoveredRow
        var stable = false
        for _ in 0...rows.count + 1 {
            let hit = rows.first { projectedYRange(of: $0, expanded: candidate).contains(p.y) }
            if hit === candidate { stable = true; break }
            candidate = hit
        }
        guard stable else { return }
        // 物理滑动只允许逐行切换：快速甩动或事件被合并（主线程忙）时，一次事件
        // 可能直接落进相隔好几行的区域，直接切换就会跳行——此时只向目标方向
        // 走一步，后续鼠标事件（或异步续走）继续走完，中间行保证依次展开。
        // 面板弹出/重排等"内容动了、光标没动"的路径不走此钳制，允许直接落位。
        if stepping, let cur = hoveredRow, let target = candidate, cur !== target,
           let ci = rows.firstIndex(of: cur), let ti = rows.firstIndex(of: target),
           abs(ti - ci) > 1 {
            setHoveredRow(rows[ci + (ti > ci ? 1 : -1)])
            DispatchQueue.main.async { [weak self] in self?.reevaluateHoverAtCursor(stepping: true) }
            return
        }
        setHoveredRow(candidate)
    }

    /// 按光标当前位置重判 hover（逐行步进的异步续走；光标停住也能走完全程）
    private func reevaluateHoverAtCursor(stepping: Bool) {
        guard window != nil else { return }
        let loc = window?.mouseLocationOutsideOfEventStream ?? .zero
        updateHoverForLocation(convert(loc, from: nil), stepping: stepping)
    }

    /// rows 顺序 + 展开态决定的最终纵向区间（视图坐标，本视图非翻转：y 越大越靠上；
    /// 与约束串接公式一致：行上缘 = 上一行下缘 - 2pt 间隔）
    private func projectedYRange(of row: MenuRow, expanded: MenuRow?) -> ClosedRange<CGFloat> {
        var lowerEdge = headerLabel.frame.minY
        for r in rows {
            let h: CGFloat = r === expanded ? MenuRow.mainHeight + MenuRow.detailHeight : MenuRow.mainHeight
            let topEdge = lowerEdge - 2
            if r === row { return (topEdge - h - 3)...(topEdge + 3) }
            lowerEdge = topEdge - h
        }
        return -1...(-1) // 不应发生：返回永不命中的哨兵区间
    }

    private func setHoveredRow(_ row: MenuRow?) {
        guard hoveredRow !== row else { return }
        hoveredRow = row
        if Self.isDemo { NSLog("PieDrop hover → %@", row?.session.tty ?? "nil") }
        if let r = row { r.setDraftText(draftProvider(r.session)) }
        rows.forEach { $0.setHovered($0 === row) }
        // 塌缩与展开合并进同一次布局事务：整列只经历一次几何过渡
        rows.forEach { $0.setExpanded($0 === row) }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layoutSubtreeIfNeeded()
        })
    }
}
