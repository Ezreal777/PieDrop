import Foundation

/// AppleScript / shell 执行工具（须在主线程调用 NSAppleScript）
enum ScriptRunner {
    @discardableResult
    static func appleScript(_ source: String) -> String? {
        appleScriptWithError(source).result
    }

    static func appleScriptWithError(_ source: String) -> (result: String?, errorCode: Int?) {
        guard let script = NSAppleScript(source: source) else { return (nil, nil) }
        var err: NSDictionary?
        let desc = script.executeAndReturnError(&err)
        if let err = err {
            let code = err[NSAppleScript.errorNumber] as? Int
            NSLog("AppleScript error code=\(code ?? -1): \(err)")
            return (nil, code)
        }
        return (desc.stringValue, nil)
    }

    static func shell(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { NSLog("shell \(path) failed: \(error)"); return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    /// 通过 /usr/bin/osascript 子进程执行（线程安全，可在后台队列调用；
    /// Apple 事件权限按责任进程归属宿主 App，与 NSAppleScript 共享已有授权）。
    /// 带超时兜底：终端 App 无响应时弃稿，绝不为一条草稿卡死线程。
    static func osascript(_ source: String, timeout: TimeInterval = 5) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", source]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { NSLog("osascript spawn failed: \(error)"); return nil }
        let seal = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in seal.signal() }
        if seal.wait(timeout: .now() + timeout) == .timedOut {
            NSLog("osascript timeout after \(timeout)s, killing")
            p.terminate()
            if seal.wait(timeout: .now() + 1) == .timedOut { p.interrupt() }
            return nil
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard p.terminationStatus == 0 else {
            NSLog("osascript exit \(p.terminationStatus)")
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
