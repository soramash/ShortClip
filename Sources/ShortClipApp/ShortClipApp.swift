import AppKit
import SwiftUI

@main
struct ShortClipApp: App {
  @StateObject private var appState: AppState
  @StateObject private var quickPasteShortcutManager: QuickPasteShortcutManager
  @StateObject private var launchAtLoginManager: LaunchAtLoginManager
  private let quickPastePanelController: QuickPastePanelController
  private let globalHotKeyMonitor: GlobalHotKeyMonitor
  private let settingsWindowOpener: SettingsWindowOpener

  init() {
    let diagnosticLogger = DiagnosticLoggerFactory.makeDefault()
    let appState = AppState(diagnosticLogger: diagnosticLogger)
    _appState = StateObject(wrappedValue: appState)
    let quickPastePanelController = QuickPastePanelController(appState: appState)
    let globalHotKeyMonitor = GlobalHotKeyMonitor(onHotKey: {
      quickPastePanelController.toggle()
    })
    let quickPasteShortcutManager = QuickPasteShortcutManager(
      registrar: globalHotKeyMonitor
    )
    _quickPasteShortcutManager = StateObject(wrappedValue: quickPasteShortcutManager)
    let launchAtLoginManager = LaunchAtLoginManager(
      logger: diagnosticLogger.log
    )
    _launchAtLoginManager = StateObject(wrappedValue: launchAtLoginManager)
    quickPastePanelController.shortcutManager = quickPasteShortcutManager

    self.quickPastePanelController = quickPastePanelController
    self.globalHotKeyMonitor = globalHotKeyMonitor
    self.settingsWindowOpener = SettingsWindowOpener(
      logger: diagnosticLogger.log
    )
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  var body: some Scene {
    MenuBarExtra("ShortClip", systemImage: "waveform.badge.magnifyingglass") {
      MenuBarContentView(
        appState: appState,
        shortcutManager: quickPasteShortcutManager,
        onOpenSettings: settingsWindowOpener.openSettings
      )
    }
    .menuBarExtraStyle(.window)

    Window(appState.localizer.text(.openLibraryAction), id: LibraryWindowView.windowID) {
      LibraryWindowView(
        appState: appState,
        shortcutManager: quickPasteShortcutManager,
        onOpenSettings: settingsWindowOpener.openSettings
      )
    }
    .defaultSize(width: 780, height: 620)

    Settings {
      ShortcutSettingsView(
        appState: appState,
        shortcutManager: quickPasteShortcutManager,
        launchAtLoginManager: launchAtLoginManager,
        localizer: appState.localizer
      )
    }
  }
}
