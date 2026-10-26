import AppKit

/// 把文本追加进目标会话的输入框（光标处插入，不覆盖、不发送）
enum Injector {
    static func inject(_ text: String, into session: CliSession) {
        switch session.terminalKind {
        case .iTerm:
            injectITerm(text: text, tty: session.tty)
        case .appleTerminal:
            injectAppleTerminal(text: text, tty: session.tty)
        }
    }

    /// iTerm2：AppleScript write text，免聚焦注入
    static func injectITerm(text: String, tty: String) {
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with tb in tabs of w
                    repeat with s in sessions of tb
                        try
                            if (tty of s) as string is "/dev/\(tty)" then
                                tell s to write text "\(ScriptRunner.escape(text))" newline no
                                return "ok"
                            end if
                        end try
                    end repeat
                end repeat
            end repeat
            return "notfound"
        end tell
        """
        let result = ScriptRunner.appleScript(script) ?? "error"
        NSLog("iTerm2 inject[\(tty)]: \(result)")
    }

    /// Terminal.app：定位到对应 tab 并激活，再用剪贴板模拟 ⌘V（先存后还原）
    static func injectAppleTerminal(text: String, tty: String) {
        let script = """
        tell application "Terminal"
            set widx to 0
            repeat with w in windows
                set widx to widx + 1
                set tidx to 0
                repeat with t in tabs of w
                    set tidx to tidx + 1
                    try
                        if (tty of t) as string is "/dev/\(tty)" then
                            set selected tab of window widx to tab tidx of window widx
                            set index of window widx to 1
                            activate
                            return "ok"
                        end if
                    end try
                end repeat
            end repeat
            return "notfound"
        end tell
        """
        let result = ScriptRunner.appleScript(script) ?? "error"
        guard result == "ok" else {
            NSLog("Terminal.app locate[\(tty)]: \(result)")
            return
        }
        usleep(180_000)  // 等窗口切换完成
        pasteViaClipboard(text)
    }

    static func pasteViaClipboard(_ text: String) {
        let pb = NSPasteboard.general
        let backup = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)
        NSLog("paste: \(text.count) chars to frontmost")
        postCmdV()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if let b = backup {
                pb.clearContents()
                pb.setString(b, forType: .string)
            }
        }
    }

    static func postCmdV() {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),   // 9 = V
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else { return }
        down.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        usleep(25_000)
        up.flags = .maskCommand
        up.post(tap: .cghidEventTap)
    }
}
