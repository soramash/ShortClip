import ApplicationServices
import Foundation

@MainActor
protocol PasteActionPerforming: AnyObject {
  var canAutoPaste: Bool { get }
  func paste() -> Bool
  func requestPermission()
}

@MainActor
final class PasteActionPerformer: PasteActionPerforming {
  var canAutoPaste: Bool {
    AXIsProcessTrusted()
  }

  func paste() -> Bool {
    guard canAutoPaste else {
      return false
    }

    guard
      let source = CGEventSource(stateID: .combinedSessionState),
      let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
    else {
      return false
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.post(tap: .cgAnnotatedSessionEventTap)
    keyUp.post(tap: .cgAnnotatedSessionEventTap)
    return true
  }

  func requestPermission() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }
}
