import AppKit
import Carbon.HIToolbox
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let hotKey = HotKeyManager()
    var statusItem: NSStatusItem?
    let panelController = DiskPanelController.shared
    private var statusLine: NSMenuItem?
    private var hotkeyItem: NSMenuItem?
    private var haloItem: NSMenuItem?
    private var menuModeItem: NSMenuItem?
    private var autostartItem: NSMenuItem?
    private let autostartKey = "PieDrop.autostart"

    /// 未设置过偏好时默认开机自启
    private var autostartEnabled: Bool {
        UserDefaults.standard.object(forKey: autostartKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: autostartKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        let (code, mods) = HotkeyConfig.load()
        hotKey.register(keyCode: code, modifiers: mods) { [weak self] in
            self?.handleHotKey()
        }
        NSLog("PieDrop launched, waiting for \(HotkeyText.display(keyCode: code, modifiers: mods))")

        // --demo：免权限演示模式，跳过辅助功能授权弹窗（demo 不注入，零权限）
        let isDemo = CommandLine.arguments.contains("--demo")
        if !isDemo {
            // 主动触发辅助功能授权（CGEvent 模拟 ⌘V 需要，不弹窗会静默失败）
            let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            let trusted = AXIsProcessTrustedWithOptions(axOptions)
            NSLog("AXIsProcessTrusted=\(trusted)")
        }

        applyAutostart()

        // --demo：免权限演示圆盘 UI（假会话，注入目标不存在，点击安全）
        // --demo-at X,Y：把面板固定弹在指定全局坐标（截图/演示用）
        if isDemo {
            var anchorOverride: NSPoint?
            if let i = CommandLine.arguments.firstIndex(of: "--demo-at"),
               i + 1 < CommandLine.arguments.count {
                let xy = CommandLine.arguments[i + 1].split(separator: ",").compactMap { Double($0) }
                if xy.count == 2 { anchorOverride = NSPoint(x: xy[0], y: xy[1]) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let fake = [
                    CliSession(pid: 0, cliName: "qodercli", tty: "ttys101", cwd: "/Users/demo/project-alpha",
                               terminalKind: .iTerm, windowTitle: "demo", itermSessionId: nil),
                    CliSession(pid: 0, cliName: "qodercli", tty: "ttys102", cwd: "/Users/demo/project-beta",
                               terminalKind: .iTerm, windowTitle: "demo", itermSessionId: nil),
                    CliSession(pid: 0, cliName: "codex", tty: "ttys103", cwd: "/Users/demo/project-gamma",
                               terminalKind: .iTerm, windowTitle: "demo", itermSessionId: nil),
                ]
                DiskPanelController.shared.present(paths: ["/Users/demo/Downloads/screenshot.png"],
                                                   sessions: fake, anchorOverride: anchorOverride)
            }
        }
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "circles.hexagonpath",
                                     accessibilityDescription: "PieDrop")
        let menu = NSMenu()
        menu.delegate = self

        statusLine = menu.addItem(withTitle: "PieDrop 运行中", action: nil, keyEquivalent: "")

        let styleEntry = NSMenuItem(title: "样式", action: nil, keyEquivalent: "")
        let styleMenu = NSMenu()
        haloItem = NSMenuItem(title: "光环（圆盘）", action: #selector(pickStyle(_:)), keyEquivalent: "")
        haloItem?.target = self
        haloItem?.representedObject = DiskPanel.Mode.halo
        menuModeItem = NSMenuItem(title: "菜单（列表）", action: #selector(pickStyle(_:)), keyEquivalent: "")
        menuModeItem?.target = self
        menuModeItem?.representedObject = DiskPanel.Mode.menu
        styleMenu.addItem(haloItem!)
        styleMenu.addItem(menuModeItem!)
        styleEntry.submenu = styleMenu
        menu.addItem(styleEntry)

        hotkeyItem = menu.addItem(withTitle: "快捷键…", action: #selector(pickHotkey(_:)), keyEquivalent: "")
        hotkeyItem?.target = self

        autostartItem = menu.addItem(withTitle: "开机自启", action: #selector(toggleAutostart(_:)), keyEquivalent: "")
        autostartItem?.target = self

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
        refreshMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenu()
    }

    private func refreshMenu() {
        let (code, mods) = HotkeyConfig.load()
        let d = HotkeyText.display(keyCode: code, modifiers: mods)
        statusLine?.title = "PieDrop 运行中 · \(d) 弹出"
        hotkeyItem?.title = "快捷键：\(d)…"
        let cur = DiskPanel.Mode.stored
        haloItem?.state = cur == .halo ? .on : .off
        menuModeItem?.state = cur == .menu ? .on : .off
        autostartItem?.state = autostartEnabled ? .on : .off
    }

    // MARK: - 开机自启（SMAppService，注册在系统登录项里）

    private func applyAutostart() {
        guard autostartEnabled else { return }
        do {
            try SMAppService.mainApp.register()
            NSLog("autostart registered")
        } catch {
            NSLog("autostart register failed: \(error)")
        }
    }

    @objc private func toggleAutostart(_ sender: NSMenuItem) {
        let next = !autostartEnabled
        UserDefaults.standard.set(next, forKey: autostartKey)
        do {
            if next {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            NSLog("autostart toggled: \(next)")
        } catch {
            NSLog("autostart toggle failed: \(error)")
        }
        refreshMenu()
    }

    @objc private func pickStyle(_ sender: NSMenuItem) {
        guard let m = sender.representedObject as? DiskPanel.Mode else { return }
        UserDefaults.standard.set(m.rawValue, forKey: "PieDrop.panelMode")
        if panelController.isVisible { panelController.dismiss() }   // 下次弹出按新样式呈现
        refreshMenu()
    }

    @objc private func pickHotkey(_ sender: NSMenuItem) {
        let old = HotkeyConfig.load()
        hotKey.unregister()   // 录制期间挂起旧热键，避免按到时弹出圆盘
        HotkeyRecorderPanel.shared.present(
            current: HotkeyText.display(keyCode: old.code, modifiers: old.mods),
            onChange: { [weak self] code, mods in
                HotkeyConfig.save(code: code, mods: mods)
                self?.hotKey.register(keyCode: code, modifiers: mods) { [weak self] in
                    self?.handleHotKey()
                }
                self?.refreshMenu()
                Toast.show("快捷键已设为 \(HotkeyText.display(keyCode: code, modifiers: mods))")
            },
            onCancelled: { [weak self] in
                self?.hotKey.register(keyCode: old.code, modifiers: old.mods) { [weak self] in
                    self?.handleHotKey()
                }
            })
    }

    func handleHotKey() {
        NSLog("hotkey fired, panelVisible=\(panelController.isVisible)")
        if panelController.isVisible {
            panelController.dismiss()
            return
        }
        let paths = FinderSelection.selectedPaths()
        NSLog("finder selection: \(paths)")
        if paths.isEmpty {
            let hk = HotkeyText.display(keyCode: HotkeyConfig.load().code, modifiers: HotkeyConfig.load().mods)
            if FinderSelection.lastError == -1743 {
                Toast.show("请在授权弹窗允许访问 Finder，再重按 \(hk)")
            } else {
                Toast.show("先在 Finder 选中文件，再按 \(hk)")
            }
            return
        }
        let sessions = SessionDetector.detect()
        NSLog("detected sessions: \(sessions.map { "\($0.cliName)@\($0.tty)→\($0.cwdName)" }.joined(separator: ", "))")
        panelController.present(paths: paths, sessions: sessions)
    }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
