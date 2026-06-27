import AppKit
import Carbon.HIToolbox
import Testing
@testable import ShortClipApp

struct QuickPasteKeyInputTests {
  @Test
  func mapsMainKeyboardDigitsWithoutModifiers() {
    let digit = QuickPasteKeyInput.digitSelection(
      forKeyCode: Int(kVK_ANSI_3),
      modifierFlags: []
    )

    #expect(digit == 3)
  }

  @Test
  func mapsKeypadDigitsWhenNumericPadFlagIsPresent() {
    let digit = QuickPasteKeyInput.digitSelection(
      forKeyCode: Int(kVK_ANSI_Keypad7),
      modifierFlags: [.numericPad]
    )

    #expect(digit == 7)
  }

  @Test
  func rejectsDigitSelectionWhenModifiersArePressed() {
    let digit = QuickPasteKeyInput.digitSelection(
      forKeyCode: Int(kVK_ANSI_1),
      modifierFlags: [.command]
    )

    #expect(digit == nil)
  }

  @Test
  func rejectsShiftedDigitSelection() {
    let digit = QuickPasteKeyInput.digitSelection(
      forKeyCode: Int(kVK_ANSI_1),
      modifierFlags: [.shift]
    )

    #expect(digit == nil)
  }
}
