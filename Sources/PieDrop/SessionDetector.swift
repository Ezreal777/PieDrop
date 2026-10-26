import AppKit
import Foundation

enum TerminalKind {
    case appleTerminal
    case iTerm
}

/// 一个"可投递的 CLI 会话"= 某终端窗口/标签页里正在跑的 agent CLI 进程
struct CliSession {
    let pid: pid_t
    let cliName: String          // qodercli / claude / codex ...
    let tty: String              // ttys004
    let cwd: String              // 启动目录
    let terminalKind: TerminalKind
    let windowTitle: String
    let itermSessionId: String?

    var label: String { cliName }
    var cwdName: String { (cwd as NSString).lastPathComponent }
    var detail: String {
        let app = terminalKind == .iTerm ? "iTerm2" : "Terminal.app"
        return "\(app) · \(tty)"
    }
}

enum SessionDetector {
    static let agentNames = ["qodercli", "claude", "codex", "gemini", "aider", "qwen", "opencode", "crush"]

    struct AgentProc {
        let pid: pid_t
        let name: String
        let tty: String
    }

    struct TermSession {
        let tty: String
        let title: String
        let kind: TerminalKind
        let itermId: String?
    }

    /// ps 扫 agent 进程 × 终端窗口按 TTY 精确配对；空闲 shell 终端也列出（可投路径）
    static func detect() -> [CliSession] {
        let (agents, shells) = scanProcesses()
        let termSessions = enumerateTerminalSessions()
        NSLog("detect: agents=\(agents.count) shells=\(shells.count) termSessions=\(termSessions.count) ttys=\(termSessions.map { $0.tty }.joined(separator: ","))")
        var out: [CliSession] = []
        var matched = Set<String>()
        for p in agents {
            guard let t = termSessions.first(where: { $0.tty == p.tty }) else { continue }
            matched.insert(p.tty)
            let cwd = workingDirectory(pid: p.pid) ?? "~"
            out.append(CliSession(pid: p.pid,
                                  cliName: p.name,
                                  tty: p.tty,
                                  cwd: cwd,
                                  terminalKind: t.kind,
                                  windowTitle: t.title,
                                  itermSessionId: t.itermId))
        }
        // 空闲终端：跑着 shell 但没有 agent CLI，也给出扇区（投路径进 shell 命令行）
        for t in termSessions where !matched.contains(t.tty) {
            guard let s = shells[t.tty] else { continue }
            let cwd = workingDirectory(pid: s.pid) ?? "~"
            out.append(CliSession(pid: s.pid,
                                  cliName: s.name,
                                  tty: t.tty,
                                  cwd: cwd,
                                  terminalKind: t.kind,
                                  windowTitle: t.title,
                                  itermSessionId: t.itermId))
        }
        var seen = Set<String>()
        return out.filter { seen.insert($0.tty).inserted }
    }

    // MARK: - 进程扫描

    static let shellNames = ["zsh", "bash", "fish"]

    /// 一次 ps 扫描同时拿 agent 进程与各 tty 上的 shell
    static func scanProcesses() -> (agents: [AgentProc], shells: [String: AgentProc]) {
        guard let out = ScriptRunner.shell("/bin/ps", ["-Ao", "pid,tty,args"]) else { return ([], [:]) }
        var agents: [AgentProc] = []
        var shells: [String: AgentProc] = [:]
        for line in out.components(separatedBy: "\n").dropFirst() {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 3, let pid = pid_t(parts[0]) else { continue }
            let tty = String(parts[1])
            let args = String(parts[2])
            guard tty.hasPrefix("ttys") else { continue }                 // 无控制终端的（tmux 服务等）跳过
            if args.contains("PieDrop") || args.contains("osascript") { continue }
            let tokens = args.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            // agent 进程：前两个 token 的文件名精确匹配（处理直接执行与 node/python 解释器两种形态），
            // 避免参数里偶然出现 CLI 名（如 --output=qodercli）造成假阳性
            var isAgent = false
            for tok in tokens.prefix(2) {
                let base = (tok as NSString).lastPathComponent
                if let hit = agentNames.first(where: { base == $0 || base.hasPrefix("\($0)-") || base.hasPrefix("\($0).js") }) {
                    agents.append(AgentProc(pid: pid, name: hit, tty: tty))
                    isAgent = true
                    break
                }
            }
            if isAgent { continue }
            // shell 进程：每个 tty 记第一个（zsh/bash/fish；登录 shell 在 ps 里显示为 -zsh）
            if shells[tty] == nil {
                for tok in tokens.prefix(2) {
                    var base = (tok as NSString).lastPathComponent
                    if base.hasPrefix("-") { base = String(base.dropFirst()) }
                    if shellNames.contains(base) {
                        shells[tty] = AgentProc(pid: pid, name: base, tty: tty)
                        break
                    }
                }
            }
        }
        return (agents, shells)
    }

    static func workingDirectory(pid: pid_t) -> String? {
        guard let out = ScriptRunner.shell("/usr/sbin/lsof", ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]) else { return nil }
        for line in out.components(separatedBy: "\n") where line.hasPrefix("n") {
            let path = String(line.dropFirst())
            if path.hasPrefix("/") { return path }
        }
        return nil
    }

    // MARK: - 终端窗口枚举

    static func enumerateTerminalSessions() -> [TermSession] {
        var list: [TermSession] = []
        let running = NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }

        // 只枚举正在运行的终端，避免 tell application 把它们拉起来
        // 用 tab 做字段分隔符：窗口标题里可能含 "|"（如 qodercli 的任务缩略）
        if running.contains("com.apple.Terminal") {
            let script = """
            set tabc to character id 9
            tell application "Terminal"
                set out to ""
                set widx to 0
                repeat with w in windows
                    set widx to widx + 1
                    repeat with t in tabs of w
                        set tt to ""
                        set wn to ""
                        try
                            set tt to (tty of t) as text
                        end try
                        try
                            set wn to (name of w) as text
                        end try
                        if tt is not "" then
                            set out to out & widx & tabc & tt & tabc & wn & linefeed
                        end if
                    end repeat
                end repeat
                return out
            end tell
            """
            if let s = ScriptRunner.appleScript(script) {
                NSLog("Terminal enum raw: \(s.prefix(400))")
                list.append(contentsOf: parseLines(s) { parts in
                    // Terminal 返回 /dev/ttysNNN，统一去掉 /dev/ 前缀再与 ps 配对
                    let tty = parts[1].replacingOccurrences(of: "/dev/", with: "")
                    guard tty.hasPrefix("ttys") else { return nil }
                    return TermSession(tty: tty, title: parts.count > 2 ? parts[2] : "",
                                       kind: .appleTerminal, itermId: nil)
                })
            }
        }

        if running.contains("com.googlecode.iterm2") {
            let script = """
            set tabc to character id 9
            tell application "iTerm2"
                set out to ""
                repeat with w in windows
                    repeat with tb in tabs of w
                        repeat with s in sessions of tb
                            set sid to ""
                            set tt to ""
                            set sn to ""
                            try
                                set sid to (id of s) as text
                            end try
                            try
                                set tt to (tty of s) as text
                            end try
                            try
                                set sn to (name of s) as text
                            end try
                            if tt is not "" then
                                set out to out & sid & tabc & tt & tabc & sn & linefeed
                            end if
                        end repeat
                    end repeat
                end repeat
                return out
            end tell
            """
            if let s = ScriptRunner.appleScript(script) {
                NSLog("iTerm enum raw: \(s.prefix(400))")
                list.append(contentsOf: parseLines(s) { parts in
                    let tty = parts[1].replacingOccurrences(of: "/dev/", with: "")
                    guard tty.hasPrefix("ttys") else { return nil }
                    return TermSession(tty: tty, title: parts.count > 2 ? parts[2] : "",
                                       kind: .iTerm, itermId: parts[0])
                })
            }
        }
        return list
    }

    static func parseLines(_ text: String, _ make: ([String]) -> TermSession?) -> [TermSession] {
        var out: [TermSession] = []
        for line in text.components(separatedBy: "\n") where line.contains("\t") {
            if let t = make(line.components(separatedBy: "\t")) { out.append(t) }
        }
        return out
    }
}
