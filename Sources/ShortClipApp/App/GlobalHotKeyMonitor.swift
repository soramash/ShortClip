import Carbon.HIToolbox
import Foundation

final class GlobalHotKeyMonitor: QuickPasteShortcutRegistering {
  private static let signature: OSType = 0x53484350
  nonisolated(unsafe) private static var eventHandlerRef: EventHandlerRef?
  nonisolated(unsafe) private static var nextID: UInt32 = 1
  nonisolated(unsafe) private static var handlers: [UInt32: () -> Void] = [:]

  private let onHotKey: () -> Void
  private let hotKeyIDValue: UInt32
  private var hotKeyRef: EventHotKeyRef?

  init(onHotKey: @escaping () -> Void) {
    self.onHotKey = onHotKey
    self.hotKeyIDValue = Self.nextID
    Self.nextID += 1
  }

  func register(shortcut: QuickPasteShortcut) -> Bool {
    stop()
    Self.installHandlerIfNeeded()
    Self.handlers[hotKeyIDValue] = onHotKey
    let hotKeyID = EventHotKeyID(
      signature: Self.signature,
      id: hotKeyIDValue
    )

    let status = RegisterEventHotKey(
      shortcut.keyCode,
      shortcut.modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    guard status == noErr else {
      Self.handlers.removeValue(forKey: hotKeyIDValue)
      return false
    }

    return true
  }

  func stop() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }

    Self.handlers.removeValue(forKey: hotKeyIDValue)
  }

  private static func installHandlerIfNeeded() {
    guard eventHandlerRef == nil else {
      return
    }

    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    InstallEventHandler(
      GetApplicationEventTarget(),
      globalHotKeyEventHandler,
      1,
      &eventType,
      nil,
      &eventHandlerRef
    )
  }

  static func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
    guard let event else {
      return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
      event,
      OSType(kEventParamDirectObject),
      OSType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &hotKeyID
    )

    guard status == noErr, hotKeyID.signature == signature else {
      return noErr
    }

    DispatchQueue.main.async {
      handlers[hotKeyID.id]?()
    }

    return noErr
  }
}

private func globalHotKeyEventHandler(
  _: EventHandlerCallRef?,
  event: EventRef?,
  _: UnsafeMutableRawPointer?
) -> OSStatus {
  GlobalHotKeyMonitor.handleHotKeyEvent(event)
}
