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

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
