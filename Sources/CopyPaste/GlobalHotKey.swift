import Carbon.HIToolbox
import CopyPasteKit
import Foundation

/// A system-wide shortcut through Carbon. Unlike an event tap, it needs no extra permission.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void
    /// False when the system refused the shortcut, for example because it is already taken.
    private(set) var isRegistered = false

    init(spec: HotKeySpec, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, context, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4350_5354), id: 1) // 'CPST'
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        isRegistered = status == noErr
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    fileprivate func fire() {
        action()
    }
}

private func hotKeyHandler(
    _ next: EventHandlerCallRef?,
    _ event: EventRef?,
    _ context: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let context else { return OSStatus(eventNotHandledErr) }
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async {
        hotKey.fire()
    }
    return noErr
}
