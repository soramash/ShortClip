import AppKit
import Foundation
import SwiftUI

@MainActor
final class QuickPastePanelController {
  private let appState: AppState
  private let panelState = QuickPastePanelState()
  var shortcutManager: QuickPasteShortcutManager?
  private var previousApp: NSRunningApplication?
  private lazy var panelDelegate = QuickPastePanelDelegate(
    onPanelDidHide: { [weak self] in
      self?.panelState.didHidePanel()
    }
  )
  private lazy var panel: NSPanel = {
    guard let shortcutManager else {
      fatalError("QuickPastePanelController.shortcutManager must be set before showing the panel")
    }

    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = true
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    panel.delegate = panelDelegate
    panel.center()

    let rootView = MenuBarContentView(
      appState: appState,
      shortcutManager: shortcutManager,
      mode: .quickPaste,
      quickPastePanelState: panelState,
      onHistorySelected: { [weak self] id in
        self?.performQuickPaste {
          self?.appState.quickPasteHistoryItem(id: id) ?? false
        }
      },
      onSnippetSelected: { [weak self] id in
        self?.performQuickPaste {
          self?.appState.quickPasteSnippet(id: id) ?? false
        }
      },
      onCloseRequested: { [weak self] in
        self?.hide()
      }
    )

    panel.contentViewController = NSHostingController(rootView: rootView)
    return panel
  }()

  init(appState: AppState) {
    self.appState = appState
  }

  func toggle() {
    guard appState.isShortClipEnabled else {
      appState.logDiagnostic("quick_paste_panel_blocked disabled=true")
      return
    }

    panel.isVisible ? hide() : show()
  }

  func show() {
    guard appState.isShortClipEnabled else {
      appState.logDiagnostic("quick_paste_panel_blocked disabled=true")
      return
    }

    let currentApp = NSWorkspace.shared.frontmostApplication
    previousApp = currentApp?.processIdentifier == ProcessInfo.processInfo.processIdentifier
      ? nil
      : currentApp

    appState.refreshAutoPasteAvailability()
    NSApp.activate(ignoringOtherApps: true)
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    panelState.didShowPanel()
  }

  func hide() {
    panelState.didHidePanel()
    panel.orderOut(nil)
  }

  private static let remoteDesktopBundleIDs: Set<String> = [
    "com.apple.ScreenSharing",
    "com.apple.RemoteDesktop",
    "com.microsoft.rdc.macos",
    "com.microsoft.rdc.osx",
    "com.vmware.horizon",
    "com.citrix.XenAppViewer",
    "com.parallels.winapp",
  ]

  private func performQuickPaste(
    action: @escaping () -> Bool
  ) {
    let targetApp = previousApp
    hide()
    targetApp?.activate(options: [])

    let isRemoteDesktop = targetApp?.bundleIdentifier
      .map { Self.remoteDesktopBundleIDs.contains($0) } ?? false
    let delay: TimeInterval = isRemoteDesktop ? 0.5 : 0.12

    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      _ = action()
    }
  }
}

private final class QuickPastePanelDelegate: NSObject, NSWindowDelegate {
  private let onPanelDidHide: () -> Void

  init(onPanelDidHide: @escaping () -> Void) {
    self.onPanelDidHide = onPanelDidHide
  }

  func windowDidResignKey(_ notification: Notification) {
    onPanelDidHide()
  }

  func windowWillClose(_ notification: Notification) {
    onPanelDidHide()
  }
}
