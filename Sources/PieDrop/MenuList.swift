import AppKit

// MARK: - 玻璃菜单（菜单 tab：单行 + hover 展开任务缩略/草稿）

final class MenuRow: NSView {
    static let mainHeight: CGFloat = 40
    static let detailHeight: CGFloat = 46

    let session: CliSession
    let index: Int
    var onSelect: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    var draftLoader: (() -> String?)?

    private let dot = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let dirLabel = NSTextField(labelWithString: "")
    private let taskLabel = NSTextField(labelWithString: "")
    private let draftLabel = NSTextField(labelWithString: "")
    private var heightC: NSLayoutConstraint!
    private var tracking: NSTrackingArea?
    private var draftLoaded = false
    private var hovered = false { didSet { refreshTint() } }
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

    func setExpanded(_ e: Bool, animated: Bool) {
        guard expanded != e else { return }
        expanded = e
        if e && !draftLoaded {
            draftLoaded = true
            let d = draftLoader?() ?? nil
            draftLabel.stringValue = (d?.isEmpty == false) ? "草稿 ▏\(d!) ▌" : "草稿 （输入框为空）"
        }
        heightC.constant = e ? Self.mainHeight + Self.detailHeight : Self.mainHeight
        taskLabel.alphaValue = e ? 1 : 0
        draftLabel.alphaValue = e ? 1 : 0
        guard animated, let sup = superview else {
            superview?.layoutSubtreeIfNeeded()
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            sup.layoutSubtreeIfNeeded()
        })
    }

    private func refreshTint() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        layer?.backgroundColor = hovered
            ? Palette.fill(for: session.cliName).withAlphaComponent(0.14).cgColor
            : NSColor.clear.cgColor
        CATransaction.commit()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) { hovered = true; onHover?(true) }
    override func mouseExited(with event: NSEvent) { hovered = false; onHover?(false) }
    override func mouseDown(with event: NSEvent) { onSelect?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

final class MenuView: NSView {
    var onPick: ((Int) -> Void)?
    private var rows: [MenuRow] = []
    private var expandedIndex: Int?

    init(frame: NSRect, sessions: [CliSession], draftProvider: @escaping (CliSession) -> String?) {
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

        var prev: NSView = header
        for (i, s) in sessions.enumerated() {
            let row = MenuRow(session: s, index: i)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.draftLoader = { draftProvider(s) }
            row.onSelect = { [weak self] in self?.onPick?(i) }
            row.onHover = { [weak self] entered in self?.handleHover(i, entered: entered) }
            addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: prev.bottomAnchor, constant: 2),
                row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            ])
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

    private func handleHover(_ index: Int, entered: Bool) {
        if entered {
            guard expandedIndex != index else { return }
            expandedIndex = index
            for (i, r) in rows.enumerated() { r.setExpanded(i == index, animated: true) }
        } else if expandedIndex == index {
            expandedIndex = nil
            rows[index].setExpanded(false, animated: true)
        }
    }
}
