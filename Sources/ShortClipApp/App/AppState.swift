import AppKit
import Foundation
import ShortClipCore
import SwiftUI

enum SnippetAvailability: Equatable {
  case available
  case locked
  case unavailable
}

@MainActor
final class AppState: ObservableObject {
  typealias PasteboardWatcherFactory = (@escaping (String) -> Void, @escaping () -> Void) -> PasteboardWatching

  @Published private(set) var history: [ClipboardEntry]
  @Published private(set) var snippets: [SnippetEntry]
  @Published private(set) var canAutoPaste: Bool
  @Published private(set) var isAutoPasteEnabled: Bool
  @Published private(set) var isShortClipEnabled: Bool
  @Published private(set) var snippetAvailability: SnippetAvailability

  private var historyStore: ClipboardHistoryStore
  private var snippetStore: SnippetStore
  private let snippetPersistence: SnippetPersistence
  private let autoPastePreferencePersistence: AutoPastePreferencePersisting
  private let pasteboardWatcherFactory: PasteboardWatcherFactory
  private let pasteActionPerformer: PasteActionPerforming
  private let diagnosticLogger: any DiagnosticLogging
  private var lastSettingsAppearance: Date?
  let localizer: AppLocalizer
  let appVersion: AppVersion
  private lazy var pasteboardWatcher: PasteboardWatching = pasteboardWatcherFactory(
    { [weak self] text in
      self?.recordClipboard(text)
    },
    { [weak self] in
      self?.pruneHistory()
    }
  )

  init(
    historyStore: ClipboardHistoryStore = ClipboardHistoryStore(),
    snippetStore: SnippetStore = SnippetStore(),
    snippetPersistence: SnippetPersistence? = nil,
    autoPastePreferencePersistence: AutoPastePreferencePersisting = UserDefaultsAutoPastePreferencePersistence(),
    pasteboardWatcherFactory: @escaping PasteboardWatcherFactory = { onCopiedText, onTick in
      PasteboardWatcher(
        onCopiedText: onCopiedText,
        onTick: onTick
      )
    },
    pasteActionPerformer: PasteActionPerforming = PasteActionPerformer(),
    diagnosticLogger: any DiagnosticLogging = DiagnosticLoggerFactory.makeDefault(),
    localizer: AppLocalizer = AppLocalizer(language: .current),
    appVersion: AppVersion = .current()
  ) {
    self.historyStore = historyStore
    self.diagnosticLogger = diagnosticLogger
    let resolvedSnippetPersistence =
      snippetPersistence
      ?? SnippetPersistenceFactory.makeDefault(diagnosticLogger: diagnosticLogger)
    self.snippetPersistence = resolvedSnippetPersistence
    self.autoPastePreferencePersistence = autoPastePreferencePersistence
    self.pasteActionPerformer = pasteActionPerformer
    self.localizer = localizer
    self.appVersion = appVersion
    self.pasteboardWatcherFactory = pasteboardWatcherFactory
    let persistedSnippets: [SnippetEntry]
    let snippetAvailability: SnippetAvailability

    diagnosticLogger.log(
      "app_state_init version=\(appVersion.displayText) bundle_path=\(Bundle.main.bundlePath) executable_path=\(Bundle.main.executablePath ?? "unknown") snippets_file=\(resolvedSnippetPersistence.fileURL.path(percentEncoded: false))"
    )

    do {
      persistedSnippets = try resolvedSnippetPersistence.load()
      snippetAvailability = .available
      diagnosticLogger.log("snippet_load_succeeded count=\(persistedSnippets.count)")
    } catch let error as SnippetPersistenceLoadError where error == .locked {
      persistedSnippets = snippetStore.snippets
      snippetAvailability = .locked
      diagnosticLogger.log("snippet_load_locked fallback_count=\(persistedSnippets.count)")
    } catch {
      persistedSnippets = snippetStore.snippets
      snippetAvailability = .unavailable
      diagnosticLogger.log(
        "snippet_load_failed error=\(String(describing: error)) fallback_count=\(persistedSnippets.count)"
      )
    }

    self.snippetStore = snippetStore.replacingSnippets(persistedSnippets)
    self.history = historyStore.history
    self.snippets = self.snippetStore.snippets
    self.canAutoPaste = pasteActionPerformer.canAutoPaste
    self.isAutoPasteEnabled = autoPastePreferencePersistence.load()
    self.isShortClipEnabled = true
    self.snippetAvailability = snippetAvailability
    pasteboardWatcher.start()
  }

  var areSnippetsLocked: Bool {
    snippetAvailability == .locked
  }

  var areSnippetsUnavailable: Bool {
    snippetAvailability != .available
  }

  var diagnosticLogPath: String {
    diagnosticLogger.fileURL.path(percentEncoded: false)
  }

  var appBundlePath: String {
    Bundle.main.bundlePath
  }

  func retrySnippetUnlock() {
    do {
      let persistedSnippets = try snippetPersistence.load()
      snippetStore = snippetStore.replacingSnippets(persistedSnippets)
      syncSnippets()
      snippetAvailability = .available
      diagnosticLogger.log("snippet_reload_succeeded count=\(persistedSnippets.count)")
    } catch let error as SnippetPersistenceLoadError where error == .locked {
      snippetAvailability = .locked
      diagnosticLogger.log("snippet_reload_locked fallback_count=\(snippetStore.snippets.count)")
    } catch {
      snippetAvailability = .unavailable
      diagnosticLogger.log(
        "snippet_reload_failed error=\(String(describing: error)) fallback_count=\(snippetStore.snippets.count)"
      )
    }
  }

  func saveSnippet(
    id: UUID?,
    title: String,
    text: String
  ) {
    guard !areSnippetsUnavailable else {
      diagnosticLogger.log("snippet_save_blocked availability=\(snippetAvailability.logValue)")
      return
    }

    if let id {
      _ = snippetStore.updateSnippet(
        id: id,
        title: title,
        text: text
      )
    } else {
      _ = snippetStore.addSnippet(
        title: title,
        text: text
      )
    }

    syncSnippets()
    persistSnippets()
    diagnosticLogger.log("snippet_save_succeeded count=\(snippetStore.snippets.count)")
  }

  func deleteSnippet(id: UUID) {
    guard !areSnippetsUnavailable else {
      diagnosticLogger.log("snippet_delete_blocked availability=\(snippetAvailability.logValue)")
      return
    }

    snippetStore.deleteSnippet(id: id)
    syncSnippets()
    persistSnippets()
    diagnosticLogger.log("snippet_delete_succeeded id=\(id.uuidString)")
  }

  func recallSnippet(id: UUID) {
    guard isShortClipEnabled else {
      diagnosticLogger.log("snippet_recall_blocked disabled=true")
      return
    }

    guard !areSnippetsUnavailable else {
      diagnosticLogger.log("snippet_recall_blocked availability=\(snippetAvailability.logValue)")
      return
    }

    guard let snippet = snippetStore.recall(id: id) else {
      return
    }

    historyStore.recordCopy(text: snippet.text)
    pasteboardWatcher.write(text: snippet.text)
    syncSnippets()
    persistSnippets()
    syncHistory()
    diagnosticLogger.log("snippet_recall_succeeded id=\(id.uuidString)")
  }

  func recallHistoryItem(id: UUID) {
    guard isShortClipEnabled else {
      diagnosticLogger.log("history_recall_blocked disabled=true")
      return
    }

    guard let entry = historyStore.recall(id: id) else {
      return
    }

    pasteboardWatcher.write(text: entry.text)
    syncHistory()
  }

  func clearHistory() {
    historyStore.clear()
    syncHistory()
  }

  func deleteHistoryItem(id: UUID) {
    historyStore.delete(id: id)
    syncHistory()
  }

  @discardableResult
  func quickPasteHistoryItem(id: UUID) -> Bool {
    guard prepareQuickPasteHistoryItem(id: id) else {
      return false
    }
    return performPaste()
  }

  @discardableResult
  func quickPasteSnippet(id: UUID) -> Bool {
    guard prepareQuickPasteSnippet(id: id) else {
      return false
    }
    return performPaste()
  }

  func prepareQuickPasteHistoryItem(id: UUID) -> Bool {
    guard isShortClipEnabled else {
      diagnosticLogger.log("quick_paste_history_blocked disabled=true")
      return false
    }

    guard let entry = historyStore.recall(id: id) else {
      return false
    }

    pasteboardWatcher.write(text: entry.text)
    syncHistory()
    return true
  }

  func prepareQuickPasteSnippet(id: UUID) -> Bool {
    guard isShortClipEnabled else {
      diagnosticLogger.log("quick_paste_snippet_blocked disabled=true")
      return false
    }

    guard !areSnippetsUnavailable else {
      diagnosticLogger.log("quick_paste_snippet_blocked availability=\(snippetAvailability.logValue)")
      return false
    }

    guard let snippet = snippetStore.recall(id: id) else {
      return false
    }

    historyStore.recordCopy(text: snippet.text)
    pasteboardWatcher.write(text: snippet.text)
    syncSnippets()
    persistSnippets()
    syncHistory()
    diagnosticLogger.log("quick_paste_snippet_succeeded id=\(id.uuidString)")
    return true
  }

  @discardableResult
  func performPasteAction() -> Bool {
    performPaste()
  }

  func requestAutoPastePermission() {
    pasteActionPerformer.requestPermission()
    canAutoPaste = pasteActionPerformer.canAutoPaste
  }

  func refreshAutoPasteAvailability() {
    canAutoPaste = pasteActionPerformer.canAutoPaste
  }

  func setAutoPasteEnabled(_ isEnabled: Bool) {
    isAutoPasteEnabled = isEnabled
    autoPastePreferencePersistence.save(isEnabled: isEnabled)
  }

  func setShortClipEnabled(_ isEnabled: Bool) {
    guard isShortClipEnabled != isEnabled else {
      return
    }

    isShortClipEnabled = isEnabled

    if isEnabled {
      pasteboardWatcher.start()
      diagnosticLogger.log("shortclip_enabled")
      return
    }

    pasteboardWatcher.stop()
    diagnosticLogger.log("shortclip_disabled")
  }

  func logDiagnostic(_ message: String) {
    diagnosticLogger.log(message)
  }

  func recordSettingsOpenRequest(source: String) -> Date {
    let requestDate = Date()
    diagnosticLogger.log("settings_open_requested source=\(source)")
    return requestDate
  }

  func recordSettingsFallbackTriggered(source: String) {
    diagnosticLogger.log("settings_open_fallback source=\(source)")
  }

  func recordSettingsViewAppeared() {
    lastSettingsAppearance = Date()
    diagnosticLogger.log("settings_view_appeared")
  }

  func didSettingsAppear(after requestDate: Date) -> Bool {
    guard let lastSettingsAppearance else {
      return false
    }

    return lastSettingsAppearance >= requestDate
  }

  private func recordClipboard(_ text: String) {
    guard isShortClipEnabled else {
      diagnosticLogger.log("clipboard_record_blocked disabled=true")
      return
    }

    historyStore.recordCopy(text: text)
    syncHistory()
  }

  private func pruneHistory() {
    historyStore.pruneExpired()
    syncHistory()
  }

  private func syncHistory() {
    history = historyStore.history
  }

  private func syncSnippets() {
    snippets = snippetStore.snippets
  }

  private func persistSnippets() {
    do {
      try snippetPersistence.save(snippets: snippetStore.snippets)
      snippetAvailability = .available
      diagnosticLogger.log("snippet_persist_succeeded count=\(snippetStore.snippets.count)")
    } catch {
      snippetAvailability = .unavailable
      diagnosticLogger.log("snippet_persist_failed error=\(String(describing: error))")
    }
  }

  private func performPaste() -> Bool {
    guard isShortClipEnabled else {
      canAutoPaste = pasteActionPerformer.canAutoPaste
      return false
    }

    guard isAutoPasteEnabled else {
      canAutoPaste = pasteActionPerformer.canAutoPaste
      return false
    }

    guard pasteActionPerformer.canAutoPaste else {
      canAutoPaste = pasteActionPerformer.canAutoPaste
      return false
    }

    let didPaste = pasteActionPerformer.paste()
    canAutoPaste = pasteActionPerformer.canAutoPaste
    return didPaste
  }
}

private extension SnippetAvailability {
  var logValue: String {
    switch self {
    case .available:
      "available"
    case .locked:
      "locked"
    case .unavailable:
      "unavailable"
    }
  }
}
