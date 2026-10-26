import AppKit

/// 读取 Finder 当前选中的文件（绝对路径）
enum FinderSelection {
    /// 最近一次 AppleScript 错误码（-1743 = 未授权自动化）
    static private(set) var lastError: Int?

    static func selectedPaths() -> [String] {
        lastError = nil
        let script = """
        tell application "Finder"
            set sel to selection as alias list
            set out to ""
            repeat with f in sel
                set out to out & (POSIX path of f) & linefeed
            end repeat
            return out
        end tell
        """
        let (out, err) = ScriptRunner.appleScriptWithError(script)
        lastError = err
        guard let out = out else { return [] }
        return out
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
