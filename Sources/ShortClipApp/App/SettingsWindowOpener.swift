import AppKit

@MainActor
struct SettingsWindowOpener {
  private let activateApp: () -> Void
  private let sendSettingsAction: () -> Bool
  private let logger: @Sendable (String) -> Void

  init(
    activateApp: @escaping () -> Void = {
      NSApplication.shared.activate(ignoringOtherApps: true)
    },
    sendSettingsAction: @escaping () -> Bool = {
      NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    },
    logger: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.activateApp = activateApp
    self.sendSettingsAction = sendSettingsAction
    self.logger = logger
  }

  func openSettings() {
    logger("settings_fallback_requested")
    activateApp()
    let didSendAction = sendSettingsAction()
    logger("settings_fallback_result sent=\(didSendAction)")
  }
}
