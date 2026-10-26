import AppKit

// MARK: - 右侧预览卡（键值式结构化布局）

final class PreviewCardView: NSView {
    private let dotView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let taskRow: NSStackView
    private let termRow: NSStackView
    private let draftRow: NSStackView
    private let taskValue = NSTextField(labelWithString: "")
    private let termValue = NSTextField(labelWithString: "")
    private let draftValue = NSTextField(labelWithString: "")
    private var kvRows: [NSStackView] = []

    private static let dark = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    private static let gray = NSColor(srgbRed: 0.53, green: 0.53, blue: 0.55, alpha: 1)
    private static let faint = NSColor(srgbRed: 0.68, green: 0.68, blue: 0.70, alpha: 1)

    override init(frame: NSRect) {
        taskValue.lineBreakMode = .byTruncatingTail
        taskValue.font = .systemFont(ofSize: 11, weight: .medium)
        taskValue.widthAnchor.constraint(lessThanOrEqualToConstant: 136).isActive = true

        termValue.lineBreakMode = .byTruncatingTail
        termValue.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        termValue.textColor = Self.gray
        termValue.widthAnchor.constraint(lessThanOrEqualToConstant: 136).isActive = true

        draftValue.lineBreakMode = .byTruncatingTail
        draftValue.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        draftValue.textColor = Self.dark
        draftValue.widthAnchor.constraint(lessThanOrEqualToConstant: 136).isActive = true

        taskRow = Self.kvRow(key: "任务", value: taskValue)
        termRow = Self.kvRow(key: "终端", value: termValue)
        draftRow = Self.kvRow(key: "草稿", value: draftValue)
        kvRows = [taskRow, termRow, draftRow]

        super.init(frame: frame)

        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 4.5
        NSLayoutConstraint.activate([
            dotView.widthAnchor.constraint(equalToConstant: 9),
            dotView.heightAnchor.constraint(equalToConstant: 9),
        ])

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = Self.dark

        let titleRow = NSStackView(views: [dotView, titleLabel])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 7

        let div1 = NSBox(); div1.boxType = .separator

        let stack = NSStackView(views: [titleRow, div1, taskRow, termRow, draftRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func kvRow(key: String, value: NSTextField) -> NSStackView {
        let k = NSTextField(labelWithString: key)
        k.font = .systemFont(ofSize: 10, weight: .medium)
        k.textColor = NSColor(srgbRed: 0.68, green: 0.68, blue: 0.70, alpha: 1)
        k.translatesAutoresizingMaskIntoConstraints = false
        k.widthAnchor.constraint(equalToConstant: 28).isActive = true
        let row = NSStackView(views: [k, value])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 5
        return row
    }

    func update(session: CliSession?, draft: String? = nil) {
        guard let s = session else { return }
        dotView.isHidden = false
        dotView.layer?.backgroundColor = Palette.fill(for: s.cliName).cgColor
        titleLabel.stringValue = "\(s.cliName) · \(s.cwdName)"
        kvRows.forEach { $0.isHidden = false }

        let thumb = SessionText.thumbnail(s)
        taskValue.stringValue = thumb.isEmpty ? "—" : SessionText.truncate(thumb, 24)
        taskValue.textColor = Palette.text(for: s.cliName)
        termValue.stringValue = s.detail
        if let d = draft, !d.isEmpty {
            draftValue.textColor = Self.dark
            draftValue.stringValue = "▏" + d + " ▌"
        } else {
            draftValue.textColor = Self.faint
            draftValue.stringValue = "（输入框为空）"
        }
    }

    func showEmpty() {
        dotView.isHidden = true
        titleLabel.stringValue = "未发现运行中的 CLI 会话"
        kvRows.forEach { $0.isHidden = true }
    }

    /// 中性初始态：不预填任何会话，保证第一次 hover 一定有可见反应
    func showNeutral() {
        dotView.isHidden = true
        titleLabel.stringValue = "悬停扇区查看会话"
        kvRows.forEach { $0.isHidden = true }
    }
}
