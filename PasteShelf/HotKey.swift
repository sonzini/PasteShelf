// Global keyboard shortcut that works while the app is in the background.
// Uses Carbon's RegisterEventHotKey, which needs no special permission and works inside the App Sandbox.

import Carbon
import Foundation

final class HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private var ref: EventHotKeyRef?
    let isRegistered: Bool

    /// - Parameters:
    ///   - keyCode: virtual key code, e.g. `kVK_ANSI_V`.
    ///   - modifiers: Carbon modifier mask, e.g. `cmdKey | shiftKey`.
    init(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        let id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.handlers[id] = handler
        HotKey.installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: OSType(0x484B4559), id: id) // 'HKEY'
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        isRegistered = (status == noErr)
        if !isRegistered { NSLog("HotKey: could not register shortcut (status \(status)); is another app using it?") }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            DispatchQueue.main.async { HotKey.handlers[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
