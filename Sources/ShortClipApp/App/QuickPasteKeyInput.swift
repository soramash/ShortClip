import AppKit
import Carbon.HIToolbox

enum QuickPasteKeyInput {
  static func digitSelection(
    forKeyCode keyCode: Int,
    modifierFlags: NSEvent.ModifierFlags
  ) -> Int? {
    guard canUseDigitSelection(modifierFlags: modifierFlags) else {
      return nil
    }

    return switch keyCode {
    case Int(kVK_ANSI_0), Int(kVK_ANSI_Keypad0):
      0
    case Int(kVK_ANSI_1), Int(kVK_ANSI_Keypad1):
      1
    case Int(kVK_ANSI_2), Int(kVK_ANSI_Keypad2):
      2
    case Int(kVK_ANSI_3), Int(kVK_ANSI_Keypad3):
      3
    case Int(kVK_ANSI_4), Int(kVK_ANSI_Keypad4):
      4
    case Int(kVK_ANSI_5), Int(kVK_ANSI_Keypad5):
      5
    case Int(kVK_ANSI_6), Int(kVK_ANSI_Keypad6):
      6
    case Int(kVK_ANSI_7), Int(kVK_ANSI_Keypad7):
      7
    case Int(kVK_ANSI_8), Int(kVK_ANSI_Keypad8):
      8
    case Int(kVK_ANSI_9), Int(kVK_ANSI_Keypad9):
      9
    default:
      nil
    }
  }

  static func canUseDigitSelection(
    modifierFlags: NSEvent.ModifierFlags
  ) -> Bool {
    let allowedFlags: NSEvent.ModifierFlags = [.numericPad]
    let activeFlags = modifierFlags.intersection(.deviceIndependentFlagsMask)

    return activeFlags.subtracting(allowedFlags).isEmpty
  }
}
