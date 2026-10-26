import Foundation

/// 读取终端屏幕尾部，提取输入框里的未发送草稿
enum DraftReader {
    /// 通过 AppleScript 拿当前屏幕文本（Terminal.app: contents of tab / iTerm2: text of session）
    static func screenText(kind: TerminalKind, tty: String) -> String? {
        let script: String
        switch kind {
        case .appleTerminal:
            script = """
            tell application "Terminal"
                set widx to 0
                repeat with w in windows
                    set widx to widx + 1
                    set tidx to 0
                    repeat with t in tabs of w
                        set tidx to tidx + 1
                        set tt to ""
                        try
                            set tt to (tty of t) as text
                        end try
                        if tt is "/dev/\(tty)" then
                            try
                                return (contents of tab tidx of window widx) as text
                            end try
                            return ""
                        end if
                    end repeat
                end repeat
                return ""
            end tell
            """
        case .iTerm:
            script = """
            tell application "iTerm2"
                repeat with w in windows
                    repeat with tb in tabs of w
                        repeat with s in sessions of tb
                            set tt to ""
                            try
                                set tt to (tty of s) as text
                            end try
                            if tt is "/dev/\(tty)" then
                                try
                                    return (text of s) as text
                                end try
                                return ""
                            end if
                        end repeat
                    end repeat
                end repeat
                return ""
            end tell
            """
        }
        return ScriptRunner.appleScript(script)
    }

    /// 草稿 = 屏幕尾部最后一行 "> " 提示符后面的文本；空输入/占位符返回 nil
    static func extractDraft(from screen: String) -> String? {
        let lines = screen.components(separatedBy: "\n").suffix(18)
        var draft: String?
        for line in lines {
            if let r = line.range(of: "^\\s*>\\s?", options: .regularExpression) {
                draft = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        guard var d = draft, !d.isEmpty else { return nil }
        if d.contains("Type your message") { return nil }   // 占位符
        if d.count > 40 { d = d.prefix(40) + "…" }
        return d
    }

    static func draft(kind: TerminalKind, tty: String) -> String? {
        guard let screen = screenText(kind: kind, tty: tty) else { return nil }
        return extractDraft(from: screen)
    }
}
