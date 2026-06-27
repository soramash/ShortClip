import AppKit
import Carbon.HIToolbox
import ShortClipCore
import SwiftUI

enum MenuBarContentMode {
  case menuBar
  case library
  case quickPaste
}

private enum QuickPasteSectionKind {
  case snippets
  case history
}

private struct QuickPasteItem: Identifiable, Equatable {
  enum Source: Equatable {
    case snippet(UUID)
    case history(UUID)
  }

  let id: String
  let source: Source
  let section: QuickPasteSectionKind
  let title: String?
  let listText: String
  let detailText: String
  let metadata: String
}

private struct HistoryManagementRow: View {
  let item: QuickPasteItem
  let isSelected: Bool
  let removeHelpText: String
  let onSelect: () -> Void
  let onDelete: () -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 10) {
      Button(action: onSelect) {
        VStack(alignment: .leading, spacing: 6) {
          Text(item.listText)
            .font(.body)
            .foregroundStyle(.primary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(item.metadata)
            .font(.caption2)
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)

      Group {
        if isHovered || isSelected {
          Button(role: .destructive, action: onDelete) {
            Image(systemName: "trash")
              .font(.caption.weight(.semibold))
              .frame(width: 24, height: 24)
          }
          .buttonStyle(.borderless)
          .help(removeHelpText)
        } else {
          Color.clear
            .frame(width: 24, height: 24)
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(.ultraThinMaterial)
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.accentColor.opacity(isSelected ? 0.16 : 0))
    }
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
    )
    .onHover { isHovered in
      self.isHovered = isHovered
    }
  }
}

struct MenuBarContentView: View {
  @Environment(\.openSettings) private var openSettings
  @Environment(\.openWindow) private var openWindow
  @ObservedObject private var appState: AppState
  @ObservedObject private var shortcutManager: QuickPasteShortcutManager
  @ObservedObject private var quickPastePanelState: QuickPastePanelState
  private let mode: MenuBarContentMode
  private let onHistorySelected: (UUID) -> Void
  private let onSnippetSelected: (UUID) -> Void
  private let onOpenSettings: (() -> Void)?
  private let onCloseRequested: (() -> Void)?
  @State private var editingSnippetID: UUID?
  @State private var isCreatingSnippet = false
  @State private var draftTitle = ""
  @State private var draftText = ""
  @State private var menuBarSelectedItemID: String?
  @State private var quickPasteSelectionModel = QuickPasteSelectionModel(itemIDs: [])
  @State private var quickPasteNumberInputState = QuickPasteNumberInputState()

  init(
    appState: AppState,
    shortcutManager: QuickPasteShortcutManager,
    mode: MenuBarContentMode = .menuBar,
    quickPastePanelState: QuickPastePanelState = QuickPastePanelState(),
    onHistorySelected: ((UUID) -> Void)? = nil,
    onSnippetSelected: ((UUID) -> Void)? = nil,
    onOpenSettings: (() -> Void)? = nil,
    onCloseRequested: (() -> Void)? = nil
  ) {
    _appState = ObservedObject(wrappedValue: appState)
    _shortcutManager = ObservedObject(wrappedValue: shortcutManager)
    _quickPastePanelState = ObservedObject(wrappedValue: quickPastePanelState)
    self.mode = mode
    self.onHistorySelected = onHistorySelected ?? { appState.recallHistoryItem(id: $0) }
    self.onSnippetSelected = onSnippetSelected ?? { appState.recallSnippet(id: $0) }
    self.onOpenSettings = onOpenSettings
    self.onCloseRequested = onCloseRequested
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      if mode == .menuBar {
        menuBarQuickAccessContent
      } else if mode == .library {
        appEnableSection
        if !appState.isShortClipEnabled {
          appDisabledBanner
        }
        shortcutSection
        if appState.areSnippetsUnavailable {
          snippetStatusBanner
        }
        menuBarLibraryContent
      } else {
        quickPasteContent
      }
      footer
    }
    .padding(14)
    .background(rootBackground)
    .frame(width: contentWidth)
    .onAppear {
      syncQuickPasteSelection()
      syncMenuBarSelection()
      resetQuickPasteNumberInput()
    }
    .onChange(of: quickPasteItemIDs) { _, _ in
      syncQuickPasteSelection()
      syncMenuBarSelection()
      resetQuickPasteNumberInput()
    }
    .onChange(of: quickPastePanelState.isKeyboardCaptureEnabled) { _, isEnabled in
      guard mode == .quickPaste, isEnabled else {
        return
      }

      quickPasteSelectionModel = QuickPasteSelectionModel(itemIDs: quickPasteItemIDs)
      resetQuickPasteNumberInput()
    }
    .onLocalKeyDown(when: mode == .quickPaste && quickPastePanelState.isKeyboardCaptureEnabled) { event in
      handleQuickPasteKeyDown(event)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(appState.localizer.text(.appTitle))
            .font(.title3.weight(.semibold))
          Text(appState.appVersion.displayText)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quinary, in: Capsule())
        }
        Spacer()
        if mode == .quickPaste {
          Text(shortcutManager.activeShortcut.displayText)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quinary, in: Capsule())
        }
      }

      Text(headerDescription)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if mode == .quickPaste {
        Text(appState.localizer.quickPasteKeyboardInstructions(
          isAutoPasteEnabled: appState.isAutoPasteEnabled
        ))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if mode == .quickPaste, appState.isAutoPasteEnabled, !appState.canAutoPaste {
        Button(appState.localizer.text(.enableAccessibilityAction)) {
          appState.requestAutoPastePermission()
        }
        .font(.caption)
      }
    }
  }

  private var headerDescription: String {
    if mode == .quickPaste {
      guard appState.isShortClipEnabled else {
        return appState.localizer.text(.appDisabledDetail)
      }

      guard appState.isAutoPasteEnabled else {
        return appState.localizer.text(.autoPasteDisabledMessage)
      }

      return appState.canAutoPaste
        ? appState.localizer.autoPasteReadyMessage(
          shortcut: shortcutManager.activeShortcut.displayText
        )
        : appState.localizer.text(.autoPasteNeedsPermissionMessage)
    }

    return appState.localizer.text(.headerDescription)
  }

  private var contentWidth: CGFloat {
    switch mode {
    case .menuBar:
      420
    case .library:
      780
    case .quickPaste:
      760
    }
  }

  private var menuBarQuickAccessContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      appEnableSection

      if !appState.isShortClipEnabled {
        appDisabledBanner
      }

      if appState.areSnippetsUnavailable {
        snippetStatusBanner
      }

      Text(appState.localizer.text(.libraryWindowDescription))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      compactSection(
        title: appState.localizer.text(.recentSnippetsTitle),
        count: appState.snippets.count,
        rows: appState.snippets.prefix(3).map(\.title),
        emptyMessage: appState.localizer.text(.snippetsEmptyState)
      )

      compactSection(
        title: appState.localizer.text(.recentHistoryTitle),
        count: appState.history.count,
        rows: appState.history.prefix(3).map { compactSingleLineText($0.text) },
        emptyMessage: appState.localizer.text(.historyEmptyState)
      )

      HStack(spacing: 8) {
        Button(appState.localizer.text(.openLibraryAction)) {
          openWindow(id: LibraryWindowView.windowID)
        }
        .buttonStyle(.borderedProminent)

        Button(appState.localizer.text(.shortcutSettingsAction)) {
          openSettingsWindow(source: "menu-bar")
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var appEnableSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle(
        appState.localizer.text(.appEnableToggleLabel),
        isOn: Binding(
          get: { appState.isShortClipEnabled },
          set: { appState.setShortClipEnabled($0) }
        )
      )
      .toggleStyle(.switch)

      Text(appState.localizer.text(.appEnableToggleHelp))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
  }

  private var appDisabledBanner: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(appState.localizer.text(.appDisabledMessage))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)

      Text(appState.localizer.text(.appDisabledDetail))
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
  }

  private var snippetStatusBanner: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(snippetStatusMessage)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)

      Text(snippetStatusDetail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if appState.areSnippetsLocked || appState.areSnippetsUnavailable {
        HStack(spacing: 8) {
          if appState.areSnippetsLocked {
            Button(appState.localizer.text(.unlockSnippetsAction)) {
              appState.retrySnippetUnlock()
            }
            .buttonStyle(.borderedProminent)
          } else {
            Button(appState.localizer.text(.retryLoadSnippetsAction)) {
              appState.retrySnippetUnlock()
            }
            .buttonStyle(.borderedProminent)
          }

          Button(appState.localizer.text(.shortcutSettingsAction)) {
            openSettingsWindow(source: "snippet-banner")
          }
          .buttonStyle(.bordered)
        }
        .font(.caption.weight(.medium))
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(appState.localizer.text(.runningAppPathLabel))
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)

        Text(appState.appBundlePath)
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)

        Text(appState.localizer.text(.diagnosticLogPathLabel))
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.top, 2)

        Text(appState.diagnosticLogPath)
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
  }

  private func compactSection(
    title: String,
    count: Int,
    rows: [String],
    emptyMessage: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title)
          .font(.headline)
        Spacer()
        Text("\(count)")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(.thinMaterial, in: Capsule())
      }

      if rows.isEmpty {
        emptyState(emptyMessage)
      } else {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(rows, id: \.self) { row in
            Text(row)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
      }
    }
  }

  private var shortcutSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Text(appState.localizer.text(.shortcutSectionTitle))
          .font(.headline)
        Spacer()
        Text(shortcutManager.activeShortcut.displayText)
          .font(.system(.caption, design: .rounded).weight(.semibold))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.thinMaterial, in: Capsule())
      }

      Text(appState.localizer.text(.shortcutSectionDescription))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      HStack {
        Button(appState.localizer.text(.shortcutSettingsAction)) {
          openSettingsWindow(source: "library")
        }
        .font(.caption.weight(.medium))
        Spacer()
      }
    }
    .padding(10)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
  }

  private var menuBarLibraryContent: some View {
    HStack(alignment: .top, spacing: 14) {
      menuBarLibraryList
      menuBarDetailPanel
    }
    .frame(height: 440)
  }

  private var menuBarLibraryList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        menuBarSection(
          title: appState.localizer.text(.snippetsSectionTitle),
          count: appState.snippets.count,
          items: snippetItems,
          emptyMessage: appState.localizer.text(.snippetsEmptyState),
          actionTitle: appState.localizer.text(.addAction),
          isActionDisabled: appState.areSnippetsUnavailable,
          action: beginCreatingSnippet
        )

        menuBarSection(
          title: appState.localizer.text(.historySectionTitle),
          count: appState.history.count,
          items: historyItems,
          emptyMessage: appState.localizer.text(.historyEmptyState),
          actionTitle: appState.localizer.text(.clearHistoryAction),
          isActionDisabled: appState.history.isEmpty,
          action: { appState.clearHistory() }
        )
      }
      .padding(.trailing, 4)
    }
    .frame(width: 370)
    .frame(maxHeight: .infinity)
  }

  @ViewBuilder
  private var menuBarDetailPanel: some View {
    if appState.areSnippetsUnavailable, (isCreatingSnippet || appState.snippets.isEmpty) {
      menuBarSnippetStatusDetail
    } else if isCreatingSnippet || (libraryItems.isEmpty && editingSnippetID == nil) {
      menuBarSnippetEditorCard(isEditing: false)
    } else if let item = selectedMenuBarItem {
      menuBarDetail(item)
    } else {
      menuBarEmptyDetail
    }
  }

  private func menuBarSection(
    title: String,
    count: Int,
    items: [QuickPasteItem],
    emptyMessage: String,
    actionTitle: String? = nil,
    isActionDisabled: Bool = false,
    action: (() -> Void)? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader(
        title: title,
        count: count,
        actionTitle: actionTitle,
        isActionDisabled: isActionDisabled,
        action: action
      )

      if items.isEmpty {
        emptyState(emptyMessage)
      } else {
        VStack(spacing: 8) {
          ForEach(items) { item in
            menuBarRow(item)
          }
        }
      }
    }
  }

  private var quickPasteContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !appState.isShortClipEnabled {
        appDisabledBanner
      } else if quickPasteItems.isEmpty {
        emptyState(appState.localizer.text(.historyEmptyState))
      } else {
        HStack(alignment: .top, spacing: 14) {
          quickPasteList
          quickPasteSidePanel
        }
        .frame(height: 420)
      }
    }
  }

  private var quickPasteList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          quickPasteSection(
            title: appState.localizer.text(.historySectionTitle),
            items: historyItems
          )
          quickPasteSection(
            title: appState.localizer.text(.snippetsSectionTitle),
            items: snippetItems
          )
        }
        .padding(.trailing, 4)
      }
      .onAppear {
        scrollQuickPasteSelection(with: proxy)
      }
      .onChange(of: quickPasteSelectionModel.selectedItemID) { _, _ in
        scrollQuickPasteSelection(with: proxy)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var quickPasteSidePanel: some View {
    Group {
      if quickPasteSelectionModel.isShowingDetail, let item = selectedQuickPasteItem {
        quickPasteDetail(item)
      } else {
        quickPasteDetailPlaceholder
      }
    }
    .frame(width: 280)
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private func quickPasteSection(
    title: String,
    items: [QuickPasteItem]
  ) -> some View {
    Group {
      if items.isEmpty {
        EmptyView()
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text(title)
            .font(.headline)
          VStack(spacing: 8) {
            ForEach(items) { item in
              quickPasteRow(item)
                .id(item.id)
            }
          }
        }
      }
    }
  }

  private var footer: some View {
    HStack {
      Text(appState.localizer.text(.footerReuseHint))
        .font(.caption2)
        .foregroundStyle(.secondary)
      Spacer()
      Button(mode == .menuBar ? appState.localizer.text(.quitAction) : appState.localizer.text(.closeAction)) {
        if mode == .menuBar {
          NSApplication.shared.terminate(nil)
          return
        }

        if mode == .library {
          NSApplication.shared.keyWindow?.close()
          return
        }

        onCloseRequested?()
      }
    }
  }

  private func sectionHeader(
    title: String,
    count: Int,
    actionTitle: String? = nil,
    isActionDisabled: Bool = false,
    action: (() -> Void)? = nil
  ) -> some View {
    HStack {
      Text(title)
        .font(.headline)
      Spacer()
      if let actionTitle, let action {
        Button(actionTitle, action: action)
          .font(.caption.weight(.medium))
          .disabled(isActionDisabled)
      }
      Text("\(count)")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(.thinMaterial, in: Capsule())
    }
  }

  private func emptyState(_ message: String) -> some View {
    Text(message)
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(10)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
  }

  private func menuBarRow(_ item: QuickPasteItem) -> some View {
    let isSelected = menuBarSelectedItemID == item.id

    if case let .history(id) = item.source {
      return AnyView(
        HistoryManagementRow(
          item: item,
          isSelected: isSelected,
          removeHelpText: appState.localizer.text(.historyRemoveAction),
          onSelect: {
            selectMenuBarItem(item)
          },
          onDelete: {
            deleteHistoryItem(id)
          }
        )
      )
    }

    return AnyView(
      Button {
        selectMenuBarItem(item)
      } label: {
        VStack(alignment: .leading, spacing: 8) {
          menuBarSnippetRow(item, isSelected: isSelected)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground(isSelected: isSelected))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
        )
      }
      .buttonStyle(.plain)
    )
  }

  private func menuBarSnippetRow(
    _ item: QuickPasteItem,
    isSelected: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(item.listText)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Spacer()

        Text(item.metadata)
          .font(.caption2)
          .foregroundStyle(isSelected ? Color.accentColor : .secondary)
      }

      Text(compactSingleLineText(item.detailText))
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func quickPasteRow(_ item: QuickPasteItem) -> some View {
    let isSelected = quickPasteSelectionModel.selectedItemID == item.id
    let rowIndex = quickPasteItemIDs.firstIndex(of: item.id).map { $0 + 1 } ?? 0

    return Button {
      activateQuickPasteItem(item)
    } label: {
      HStack(alignment: .center, spacing: 10) {
        Text("\(rowIndex)")
          .font(.caption.weight(.bold))
          .foregroundStyle(isSelected ? Color.accentColor : .secondary)
          .frame(width: 22, height: 22)
          .background(.thinMaterial, in: Circle())

        VStack(alignment: .leading, spacing: 6) {
          Text(item.listText)
            .font(item.section == .snippets ? .subheadline.weight(.semibold) : .body)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(item.metadata)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .trailing, spacing: 6) {
          if isSelected {
            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(Color.accentColor)
            Image(systemName: "return")
              .font(.caption.weight(.semibold))
              .foregroundStyle(Color.accentColor)
          }
        }
        .frame(width: 16)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(rowBackground(isSelected: isSelected))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }

  private func rowBackground(isSelected: Bool) -> some ShapeStyle {
    isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.16)) : AnyShapeStyle(.ultraThinMaterial)
  }

  private var snippetItems: [QuickPasteItem] {
    appState.snippets.map {
      QuickPasteItem(
        id: "snippet-\($0.id.uuidString)",
        source: .snippet($0.id),
        section: .snippets,
        title: $0.title,
        listText: $0.title,
        detailText: $0.text,
        metadata: relativeDate($0.updatedAt)
      )
    }
  }

  private var historyItems: [QuickPasteItem] {
    appState.history.map {
      QuickPasteItem(
        id: "history-\($0.id.uuidString)",
        source: .history($0.id),
        section: .history,
        title: nil,
        listText: compactSingleLineText($0.text),
        detailText: $0.text,
        metadata: relativeDate($0.copiedAt)
      )
    }
  }

  private var libraryItems: [QuickPasteItem] {
    QuickPasteItemOrdering.forLibrary(
      snippetItems: snippetItems,
      historyItems: historyItems
    )
  }

  private var quickPasteItems: [QuickPasteItem] {
    QuickPasteItemOrdering.forQuickPaste(
      snippetItems: snippetItems,
      historyItems: historyItems
    )
  }

  private var quickPasteItemIDs: [String] {
    quickPasteItems.map(\.id)
  }

  private var libraryItemIDs: [String] {
    libraryItems.map(\.id)
  }

  private var selectedMenuBarItem: QuickPasteItem? {
    guard let selectedItemID = menuBarSelectedItemID else {
      return nil
    }

    return libraryItems.first(where: { $0.id == selectedItemID })
  }

  private var selectedQuickPasteItem: QuickPasteItem? {
    guard let selectedItemID = quickPasteSelectionModel.selectedItemID else {
      return nil
    }

    return quickPasteItems.first(where: { $0.id == selectedItemID })
  }

  private func syncMenuBarSelection() {
    guard mode == .library else {
      return
    }

    guard !libraryItems.isEmpty else {
      menuBarSelectedItemID = nil
      return
    }

    guard let selectedItemID = menuBarSelectedItemID else {
      menuBarSelectedItemID = libraryItems.first?.id
      return
    }

    guard libraryItemIDs.contains(selectedItemID) else {
      menuBarSelectedItemID = libraryItems.first?.id
      return
    }
  }

  private func syncQuickPasteSelection() {
    guard mode == .quickPaste else {
      return
    }

    quickPasteSelectionModel = quickPasteSelectionModel.updatingItemIDs(quickPasteItemIDs)
  }

  private func activateSelectedQuickPasteItem() {
    guard let item = quickPasteItems.first(where: { $0.id == quickPasteSelectionModel.selectedItemID }) else {
      return
    }

    activateQuickPasteItem(item)
  }

  private func activateQuickPasteItem(_ item: QuickPasteItem) {
    guard appState.isShortClipEnabled else {
      return
    }

    switch item.source {
    case let .snippet(id):
      onSnippetSelected(id)
    case let .history(id):
      onHistorySelected(id)
    }
  }

  private func selectMenuBarItem(_ item: QuickPasteItem) {
    menuBarSelectedItemID = item.id
    resetDraft()
  }

  private func handleQuickPasteKeyDown(_ event: NSEvent) -> Bool {
    guard mode == .quickPaste else {
      return false
    }

    if let digit = QuickPasteKeyInput.digitSelection(
      forKeyCode: Int(event.keyCode),
      modifierFlags: event.modifierFlags
    ) {
      let inputResult = quickPasteNumberInputState.registeringDigit(
        digit,
        now: Date(),
        maxRowNumber: quickPasteItemIDs.count
      )
      quickPasteNumberInputState = inputResult.state

      if let rowNumber = inputResult.selectedRowNumber {
        quickPasteSelectionModel = quickPasteSelectionModel.selectRowNumber(rowNumber)
      }

      return true
    }

    switch Int(event.keyCode) {
    case Int(kVK_UpArrow):
      resetQuickPasteNumberInput()
      quickPasteSelectionModel = quickPasteSelectionModel.moveUp()
      return true
    case Int(kVK_DownArrow):
      resetQuickPasteNumberInput()
      quickPasteSelectionModel = quickPasteSelectionModel.moveDown()
      return true
    case Int(kVK_RightArrow):
      resetQuickPasteNumberInput()
      quickPasteSelectionModel = quickPasteSelectionModel.showDetail()
      return true
    case Int(kVK_LeftArrow):
      resetQuickPasteNumberInput()
      quickPasteSelectionModel = quickPasteSelectionModel.hideDetail()
      return true
    case Int(kVK_Return), Int(kVK_ANSI_KeypadEnter):
      resetQuickPasteNumberInput()
      activateSelectedQuickPasteItem()
      return true
    case Int(kVK_Escape):
      resetQuickPasteNumberInput()
      onCloseRequested?()
      return true
    default:
      return false
    }
  }

  private func resetQuickPasteNumberInput() {
    quickPasteNumberInputState = quickPasteNumberInputState.reset()
  }

  private func relativeDate(_ date: Date) -> String {
    date.formatted(
      .relative(
        presentation: .named,
        unitsStyle: .wide
      )
    )
  }

  private func menuBarDetail(_ item: QuickPasteItem) -> some View {
    switch item.source {
    case let .snippet(id):
      if appState.areSnippetsUnavailable {
        return AnyView(menuBarSnippetStatusDetail)
      }
      if let snippet = appState.snippets.first(where: { $0.id == id }) {
        if editingSnippetID == snippet.id {
          return AnyView(menuBarSnippetEditorCard(isEditing: true))
        } else {
          return AnyView(menuBarSnippetDetail(snippet))
        }
      } else {
        return AnyView(menuBarEmptyDetail)
      }
    case let .history(id):
      if let entry = appState.history.first(where: { $0.id == id }) {
        return AnyView(menuBarHistoryDetail(entry))
      } else {
        return AnyView(menuBarEmptyDetail)
      }
    }
  }

  private func menuBarSnippetEditorCard(isEditing: Bool) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(appState.localizer.text(.snippetsSectionTitle))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      SnippetEditorView(
        title: $draftTitle,
        text: $draftText,
        isEditing: isEditing,
        localizer: appState.localizer,
        showsContainerBackground: false,
        onSave: saveSnippet,
        onCancel: resetDraft
      )
    }
    .padding(14)
    .frame(width: 368)
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private func menuBarSnippetDetail(_ snippet: SnippetEntry) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(appState.localizer.text(.snippetsSectionTitle))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(snippet.title)
        .font(.headline)
        .lineLimit(3)

      ScrollView {
        Text(snippet.text)
          .font(.body)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Divider()

      Text(relativeDate(snippet.updatedAt))
        .font(.caption2)
        .foregroundStyle(.secondary)

      HStack {
        Button(appState.localizer.text(.snippetActionRecall)) {
          onSnippetSelected(snippet.id)
        }
        .disabled(!appState.isShortClipEnabled)

        Button(appState.localizer.text(.snippetActionEdit)) {
          beginEditingSnippet(snippet)
        }
        .disabled(appState.areSnippetsUnavailable)

        Spacer()

        Button(appState.localizer.text(.snippetActionDelete), role: .destructive) {
          deleteSnippet(snippet.id)
        }
        .disabled(appState.areSnippetsUnavailable)
      }
      .font(.caption.weight(.medium))
    }
    .padding(14)
    .frame(width: 368)
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private func menuBarHistoryDetail(_ entry: ClipboardEntry) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(appState.localizer.text(.historySectionTitle))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(compactSingleLineText(entry.text))
        .font(.headline)
        .lineLimit(3)

      ScrollView {
        Text(entry.text)
          .font(.body)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Divider()

      Text(relativeDate(entry.copiedAt))
        .font(.caption2)
        .foregroundStyle(.secondary)

      HStack {
        Button(appState.localizer.text(.snippetActionRecall)) {
          onHistorySelected(entry.id)
        }
        .disabled(!appState.isShortClipEnabled)

        Spacer()

        Button(appState.localizer.text(.snippetActionDelete), role: .destructive) {
          deleteHistoryItem(entry.id)
        }
      }
      .font(.caption.weight(.medium))
    }
    .padding(14)
    .frame(width: 368)
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private var menuBarEmptyDetail: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(appState.localizer.text(.headerDescription))
        .font(.subheadline.weight(.semibold))

      Text(appState.localizer.text(.footerReuseHint))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Spacer()
    }
    .padding(14)
    .frame(width: 368)
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private var menuBarSnippetStatusDetail: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(snippetStatusMessage)
        .font(.headline)
        .foregroundStyle(.orange)

      Text(snippetStatusDetail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if appState.areSnippetsLocked {
        Button(appState.localizer.text(.shortcutSettingsAction)) {
          openSettingsWindow(source: "snippet-status")
        }
        .buttonStyle(.bordered)
      }

      Text(appState.diagnosticLogPath)
        .font(.caption2.monospaced())
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)

      Spacer()
    }
    .padding(14)
    .frame(width: 368)
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private func quickPasteDetail(_ item: QuickPasteItem) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(quickPasteSectionTitle(for: item.section))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(item.title ?? quickPasteSectionTitle(for: item.section))
        .font(.headline)
        .lineLimit(3)

      ScrollView {
        Text(item.detailText)
          .font(.body)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Divider()

      Text(item.metadata)
        .font(.caption2)
        .foregroundStyle(.secondary)

      Text(appState.localizer.quickPasteDetailInstructions(
        isAutoPasteEnabled: appState.isAutoPasteEnabled
      ))
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private var quickPasteDetailPlaceholder: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(shortcutManager.activeShortcut.displayText)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(appState.localizer.text(.quickPasteDetailPlaceholder))
        .font(.subheadline.weight(.semibold))

      Text(appState.localizer.quickPasteDetailInstructions(
        isAutoPasteEnabled: appState.isAutoPasteEnabled
      ))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Spacer()
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private var rootBackground: some View {
    RoundedRectangle(cornerRadius: 18, style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(Color.white.opacity(0.12), lineWidth: 1)
      )
  }

  private func quickPasteSectionTitle(for section: QuickPasteSectionKind) -> String {
    switch section {
    case .snippets:
      appState.localizer.text(.snippetsSectionTitle)
    case .history:
      appState.localizer.text(.historySectionTitle)
    }
  }

  private func compactSingleLineText(_ text: String) -> String {
    text
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }

  private var snippetStatusMessage: String {
    switch appState.snippetAvailability {
    case .available:
      appState.localizer.text(.snippetsSectionTitle)
    case .locked:
      appState.localizer.text(.snippetLockedMessage)
    case .unavailable:
      appState.localizer.text(.snippetUnavailableMessage)
    }
  }

  private var snippetStatusDetail: String {
    switch appState.snippetAvailability {
    case .available:
      appState.localizer.text(.snippetsEmptyState)
    case .locked:
      appState.localizer.text(.snippetLockedDetail)
    case .unavailable:
      appState.localizer.text(.snippetUnavailableDetail)
    }
  }

  private func openSettingsWindow(source: String) {
    let requestDate = appState.recordSettingsOpenRequest(source: source)
    NSApplication.shared.activate(ignoringOtherApps: true)
    openSettings()

    guard let onOpenSettings else {
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      guard !appState.didSettingsAppear(after: requestDate) else {
        return
      }

      appState.recordSettingsFallbackTriggered(source: source)
      onOpenSettings()
    }
  }

  private func scrollQuickPasteSelection(with proxy: ScrollViewProxy) {
    guard let selectedItemID = quickPasteSelectionModel.selectedItemID else {
      return
    }

    DispatchQueue.main.async {
      withAnimation(.easeInOut(duration: 0.12)) {
        proxy.scrollTo(selectedItemID, anchor: .center)
      }
    }
  }

  private func beginCreatingSnippet() {
    guard !appState.areSnippetsUnavailable else {
      return
    }

    isCreatingSnippet = true
    editingSnippetID = nil
    draftTitle = ""
    draftText = ""
  }

  private func beginEditingSnippet(_ snippet: SnippetEntry) {
    guard !appState.areSnippetsUnavailable else {
      return
    }

    isCreatingSnippet = false
    editingSnippetID = snippet.id
    draftTitle = snippet.title
    draftText = snippet.text
    menuBarSelectedItemID = itemID(for: .snippet(snippet.id))
  }

  private func deleteSnippet(_ snippetID: UUID) {
    if editingSnippetID == snippetID || isCreatingSnippet {
      resetDraft()
    }

    appState.deleteSnippet(id: snippetID)
  }

  private func deleteHistoryItem(_ historyItemID: UUID) {
    appState.deleteHistoryItem(id: historyItemID)
  }

  private func itemID(for source: QuickPasteItem.Source) -> String {
    switch source {
    case let .snippet(id):
      "snippet-\(id.uuidString)"
    case let .history(id):
      "history-\(id.uuidString)"
    }
  }

  private func saveSnippet() {
    guard !appState.areSnippetsUnavailable else {
      return
    }

    let savedSnippetID = editingSnippetID
    appState.saveSnippet(
      id: editingSnippetID,
      title: draftTitle,
      text: draftText
    )

    let nextSelectedSnippetID = savedSnippetID ?? appState.snippets.first?.id
    resetDraft()

    if let nextSelectedSnippetID {
      menuBarSelectedItemID = itemID(for: .snippet(nextSelectedSnippetID))
    }
  }

  private func resetDraft() {
    isCreatingSnippet = false
    editingSnippetID = nil
    draftTitle = ""
    draftText = ""
  }
}
