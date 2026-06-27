import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutSettingsView: View {
  @ObservedObject private var appState: AppState
  @ObservedObject private var shortcutManager: QuickPasteShortcutManager
  @ObservedObject private var launchAtLoginManager: LaunchAtLoginManager
  private let localizer: AppLocalizer
  @State private var isRecording = false
  @State private var feedback: QuickPasteShortcutApplyResult?

  init(
    appState: AppState,
    shortcutManager: QuickPasteShortcutManager,
    launchAtLoginManager: LaunchAtLoginManager,
    localizer: AppLocalizer
  ) {
    _appState = ObservedObject(wrappedValue: appState)
    _shortcutManager = ObservedObject(wrappedValue: shortcutManager)
    _launchAtLoginManager = ObservedObject(wrappedValue: launchAtLoginManager)
    self.localizer = localizer
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text(localizer.text(.shortcutSectionTitle))
          .font(.title2.weight(.semibold))

        Text(localizer.text(.shortcutSectionDescription))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        appEnableCard
        currentShortcutCard
        autoPasteCard
        launchAtLoginCard

        if let statusMessage {
          Text(statusMessage)
            .font(.caption)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }

        HStack(spacing: 10) {
          Button(
            isRecording
              ? localizer.text(.cancelAction)
              : localizer.text(.shortcutRecorderAction)
          ) {
            feedback = nil
            isRecording.toggle()
          }

          Button(localizer.text(.shortcutRestoreDefaultAction)) {
            feedback = shortcutManager.restoreDefaultShortcut()
            isRecording = false
          }
          .disabled(shortcutManager.activeShortcut == .defaultValue)
        }

        Text(localizer.text(.shortcutConflictGuidance))
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .safeAreaPadding(.top, 12)
    .frame(minWidth: 460, minHeight: 360, alignment: .topLeading)
    .onAppear {
      appState.recordSettingsViewAppeared()
      launchAtLoginManager.refreshStatus()
    }
    .onDisappear {
      isRecording = false
    }
    .onLocalKeyDown(when: isRecording) { event in
      handleRecording(event)
    }
  }

  private var currentShortcutCard: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(localizer.text(.shortcutCurrentLabel))
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
        Text(shortcutManager.activeShortcut.displayText)
          .font(.system(.title3, design: .rounded).weight(.semibold))
      }

      Spacer()
    }
    .padding(14)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private var appEnableCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Toggle(
        localizer.text(.appEnableToggleLabel),
        isOn: Binding(
          get: { appState.isShortClipEnabled },
          set: { appState.setShortClipEnabled($0) }
        )
      )
      .toggleStyle(.switch)

      Text(localizer.text(.appEnableToggleHelp))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if !appState.isShortClipEnabled {
        Text(localizer.text(.appDisabledDetail))
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(14)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private var autoPasteCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Toggle(
        localizer.text(.autoPasteToggleLabel),
        isOn: Binding(
          get: { appState.isAutoPasteEnabled },
          set: { appState.setAutoPasteEnabled($0) }
        )
      )
      .toggleStyle(.switch)

      Text(localizer.text(.autoPasteToggleHelp))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if appState.isAutoPasteEnabled, !appState.canAutoPaste {
        Button(localizer.text(.enableAccessibilityAction)) {
          appState.requestAutoPastePermission()
        }
        .font(.caption.weight(.medium))
      }
    }
    .padding(14)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private var launchAtLoginCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Toggle(
        localizer.text(.launchAtLoginToggleLabel),
        isOn: Binding(
          get: { launchAtLoginManager.isEnabled },
          set: { launchAtLoginManager.setLaunchAtLoginEnabled($0) }
        )
      )
      .toggleStyle(.switch)

      Text(localizer.text(.launchAtLoginToggleHelp))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if launchAtLoginManager.needsApproval {
        Text(localizer.text(.launchAtLoginApprovalHelp))
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)

        Button(localizer.text(.openLoginItemsAction)) {
          launchAtLoginManager.openSystemSettingsLoginItems()
        }
        .font(.caption.weight(.medium))
      }
    }
    .padding(14)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private var statusMessage: String? {
    if isRecording {
      return localizer.text(.shortcutRecorderPrompt)
    }

    guard let feedback else {
      return nil
    }

    switch feedback {
    case .updated:
      return localizer.text(.shortcutUpdatedMessage)
    case .invalidShortcut:
      return localizer.text(.shortcutValidationError)
    case .registrationFailed:
      return localizer.text(.shortcutRegistrationError)
    }
  }

  private var statusColor: Color {
    guard !isRecording, let feedback else {
      return .accentColor
    }

    switch feedback {
    case .updated:
      return .accentColor
    case .invalidShortcut, .registrationFailed:
      return .orange
    }
  }

  private func handleRecording(_ event: NSEvent) -> Bool {
    if Int(event.keyCode) == Int(kVK_Escape) {
      isRecording = false
      feedback = nil
      return true
    }

    guard let shortcut = QuickPasteShortcut.from(event: event) else {
      return true
    }

    let result = shortcutManager.applyShortcut(shortcut)
    feedback = result
    if result != .invalidShortcut {
      isRecording = false
    }

    return true
  }
}
