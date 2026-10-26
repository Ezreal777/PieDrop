import Carbon.HIToolbox
import Foundation

/// Carbon 全局热键注册
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var box: HandlerBox?

    final class HandlerBox {
        let handler: () -> Void
        init(_ h: @escaping () -> Void) { handler = h }
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        unregister()   // 支持换键重注册
        box = HandlerBox(handler)
        guard let box = box else { return }
        let userData = Unmanaged.passUnretained(box).toOpaque()

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, userData in
            guard let ud = userData else { return noErr }
            let b = Unmanaged<HandlerBox>.fromOpaque(ud).takeUnretainedValue()
            b.handler()
            return noErr
        }
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, userData, &handlerRef)
        let hotID = EventHotKeyID(signature: OSType(0x5044484B) /* "PDHK" */, id: 1)
        let regStatus = RegisterEventHotKey(keyCode, modifiers, hotID, GetApplicationEventTarget(), 0, &hotKeyRef)
        NSLog("HotKey install=\(installStatus) register=\(regStatus) code=\(keyCode) mods=\(modifiers)")
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let h = handlerRef {
            RemoveEventHandler(h)
            handlerRef = nil
        }
        box = nil
    }
}
