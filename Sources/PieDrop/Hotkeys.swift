import Carbon.HIToolbox
import Foundation

/// 快捷键持久化（Carbon keyCode + 修饰键掩码）
enum HotkeyConfig {
    static let codeKey = "PieDrop.hotKeyCode"
    static let modsKey = "PieDrop.hotKeyModifiers"

    static var fallback: (code: UInt32, mods: UInt32) {
        (UInt32(kVK_ANSI_F), UInt32(controlKey | optionKey))
    }

    static func load() -> (code: UInt32, mods: UInt32) {
        let d = UserDefaults.standard
        let code = UInt32(bitPattern: Int32(d.integer(forKey: codeKey)))
        let mods = UInt32(bitPattern: Int32(d.integer(forKey: modsKey)))
        guard code != 0, mods != 0 else { return fallback }
        return (code, mods)
    }

    static func save(code: UInt32, mods: UInt32) {
        let d = UserDefaults.standard
        d.set(Int(Int32(bitPattern: code)), forKey: codeKey)
        d.set(Int(Int32(bitPattern: mods)), forKey: modsKey)
    }
}

/// 快捷键的可读展示（⌃⌥⇧⌘ + 键名）
enum HotkeyText {
    static let keyNames: [UInt32: String] = {
        var m: [UInt32: String] = [:]
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let letterCodes: [UInt32] = [
            UInt32(kVK_ANSI_A), UInt32(kVK_ANSI_B), UInt32(kVK_ANSI_C), UInt32(kVK_ANSI_D), UInt32(kVK_ANSI_E),
            UInt32(kVK_ANSI_F), UInt32(kVK_ANSI_G), UInt32(kVK_ANSI_H), UInt32(kVK_ANSI_I), UInt32(kVK_ANSI_J),
            UInt32(kVK_ANSI_K), UInt32(kVK_ANSI_L), UInt32(kVK_ANSI_M), UInt32(kVK_ANSI_N), UInt32(kVK_ANSI_O),
            UInt32(kVK_ANSI_P), UInt32(kVK_ANSI_Q), UInt32(kVK_ANSI_R), UInt32(kVK_ANSI_S), UInt32(kVK_ANSI_T),
            UInt32(kVK_ANSI_U), UInt32(kVK_ANSI_V), UInt32(kVK_ANSI_W), UInt32(kVK_ANSI_X), UInt32(kVK_ANSI_Y),
            UInt32(kVK_ANSI_Z),
        ]
        for (i, c) in letterCodes.enumerated() { m[c] = String(letters[letters.index(letters.startIndex, offsetBy: i)]) }
        let digits: [(UInt32, String)] = [
            (UInt32(kVK_ANSI_0), "0"), (UInt32(kVK_ANSI_1), "1"), (UInt32(kVK_ANSI_2), "2"), (UInt32(kVK_ANSI_3), "3"),
            (UInt32(kVK_ANSI_4), "4"), (UInt32(kVK_ANSI_5), "5"), (UInt32(kVK_ANSI_6), "6"), (UInt32(kVK_ANSI_7), "7"),
            (UInt32(kVK_ANSI_8), "8"), (UInt32(kVK_ANSI_9), "9"),
        ]
        digits.forEach { m[$0.0] = $0.1 }
        let punct: [(UInt32, String)] = [
            (UInt32(kVK_ANSI_Grave), "`"), (UInt32(kVK_ANSI_Minus), "-"), (UInt32(kVK_ANSI_Equal), "="),
            (UInt32(kVK_ANSI_LeftBracket), "["), (UInt32(kVK_ANSI_RightBracket), "]"),
            (UInt32(kVK_ANSI_Semicolon), ";"), (UInt32(kVK_ANSI_Quote), "'"),
            (UInt32(kVK_ANSI_Comma), ","), (UInt32(kVK_ANSI_Period), "."), (UInt32(kVK_ANSI_Slash), "/"),
            (UInt32(kVK_ANSI_Backslash), "\\"),
        ]
        punct.forEach { m[$0.0] = $0.1 }
        let special: [(UInt32, String)] = [
            (UInt32(kVK_Space), "空格"), (UInt32(kVK_Return), "⏎"), (UInt32(kVK_Tab), "⇥"),
            (UInt32(kVK_Delete), "⌫"), (UInt32(kVK_ForwardDelete), "⌦"),
            (UInt32(kVK_Home), "↖"), (UInt32(kVK_End), "↘"),
            (UInt32(kVK_PageUp), "⇞"), (UInt32(kVK_PageDown), "⇟"),
            (UInt32(kVK_UpArrow), "↑"), (UInt32(kVK_DownArrow), "↓"),
            (UInt32(kVK_LeftArrow), "←"), (UInt32(kVK_RightArrow), "→"),
            (UInt32(kVK_F1), "F1"), (UInt32(kVK_F2), "F2"), (UInt32(kVK_F3), "F3"), (UInt32(kVK_F4), "F4"),
            (UInt32(kVK_F5), "F5"), (UInt32(kVK_F6), "F6"), (UInt32(kVK_F7), "F7"), (UInt32(kVK_F8), "F8"),
            (UInt32(kVK_F9), "F9"), (UInt32(kVK_F10), "F10"), (UInt32(kVK_F11), "F11"), (UInt32(kVK_F12), "F12"),
            (UInt32(kVK_Escape), "esc"),
        ]
        special.forEach { m[$0.0] = $0.1 }
        return m
    }()

    static func keyName(_ code: UInt32) -> String {
        keyNames[code] ?? String(format: "Key 0x%02X", code)
    }

    static func modSymbols(_ mods: UInt32) -> String {
        var s = ""
        if mods & UInt32(controlKey) != 0 { s += "⌃" }
        if mods & UInt32(optionKey) != 0 { s += "⌥" }
        if mods & UInt32(shiftKey) != 0 { s += "⇧" }
        if mods & UInt32(cmdKey) != 0 { s += "⌘" }
        return s
    }

    static func display(keyCode: UInt32, modifiers: UInt32) -> String {
        modSymbols(modifiers) + keyName(keyCode)
    }
}
