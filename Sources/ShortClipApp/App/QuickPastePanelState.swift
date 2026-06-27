import SwiftUI

final class QuickPastePanelState: ObservableObject {
  @Published private(set) var isKeyboardCaptureEnabled = false

  func didShowPanel() {
    isKeyboardCaptureEnabled = true
  }

  func didHidePanel() {
    isKeyboardCaptureEnabled = false
  }
}
