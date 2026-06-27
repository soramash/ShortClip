import AppKit
import SwiftUI

struct LibraryWindowView: View {
  static let windowID = "library"

  @ObservedObject private var appState: AppState
  @ObservedObject private var shortcutManager: QuickPasteShortcutManager
  private let onOpenSettings: () -> Void

  init(
    appState: AppState,
    shortcutManager: QuickPasteShortcutManager,
    onOpenSettings: @escaping () -> Void
  ) {
    _appState = ObservedObject(wrappedValue: appState)
    _shortcutManager = ObservedObject(wrappedValue: shortcutManager)
    self.onOpenSettings = onOpenSettings
  }

  var body: some View {
    MenuBarContentView(
      appState: appState,
      shortcutManager: shortcutManager,
      mode: .library,
      onOpenSettings: onOpenSettings,
      onCloseRequested: {
        NSApplication.shared.keyWindow?.close()
      }
    )
  }
}
