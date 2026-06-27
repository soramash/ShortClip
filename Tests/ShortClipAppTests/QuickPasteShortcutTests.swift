import Carbon.HIToolbox
import Testing
@testable import ShortClipApp

struct QuickPasteShortcutTests {
  @Test
  func defaultShortcutUsesCommandShiftV() {
    #expect(QuickPasteShortcut.defaultValue == QuickPasteShortcut(
      keyCode: UInt32(kVK_ANSI_V),
      modifiers: UInt32(cmdKey | shiftKey)
    ))
    #expect(QuickPasteShortcut.defaultValue.displayText == "⌘⇧V")
  }

  @Test
  func rejectsShortcutWithoutPrimaryModifier() {
    let result = QuickPasteShortcut(
      keyCode: UInt32(kVK_ANSI_V),
      modifiers: UInt32(shiftKey)
    ).validationResult

    #expect(result == .missingPrimaryModifier)
  }

  @Test
  func acceptsShortcutWithCommandModifier() {
    let result = QuickPasteShortcut(
      keyCode: UInt32(kVK_ANSI_V),
      modifiers: UInt32(cmdKey | shiftKey)
    ).validationResult

    #expect(result == .valid)
  }
}
