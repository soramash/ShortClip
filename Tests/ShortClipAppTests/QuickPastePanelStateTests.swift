import Testing
@testable import ShortClipApp

@MainActor
struct QuickPastePanelStateTests {
  @Test
  func keyboardCaptureIsDisabledByDefault() {
    let state = QuickPastePanelState()

    #expect(state.isKeyboardCaptureEnabled == false)
  }

  @Test
  func keyboardCaptureTogglesWithPanelVisibility() {
    let state = QuickPastePanelState()

    state.didShowPanel()
    #expect(state.isKeyboardCaptureEnabled)

    state.didHidePanel()
    #expect(state.isKeyboardCaptureEnabled == false)
  }
}
