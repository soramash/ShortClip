import Foundation
import Testing
@testable import ShortClipApp
@testable import ShortClipCore

@MainActor
struct AppStateQuickPasteTests {
  @Test
  func loadsPersistedSnippetsWhenAppStateStarts() {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("snippets.json")
    let persistence = SnippetPersistence(fileURL: fileURL)
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let firstAppState = AppState(
      snippetPersistence: persistence,
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    firstAppState.saveSnippet(
      id: nil,
      title: "Persisted",
      text: "value"
    )

    let secondAppState = AppState(
      snippetPersistence: persistence,
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    #expect(secondAppState.snippets.map(\.title) == ["Persisted"])
    #expect(secondAppState.snippets.map(\.text) == ["value"])
  }

  @Test
  func quickPasteHistoryCopiesTextAndRequestsPaste() throws {
    let entry = ClipboardEntry(
      id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
      text: "alpha",
      copiedAt: Date(timeIntervalSince1970: 1_000)
    )
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    let appState = AppState(
      historyStore: ClipboardHistoryStore(
        history: [entry],
        now: { Date(timeIntervalSince1970: 1_100) }
      ),
      snippetStore: SnippetStore(),
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    let result = appState.quickPasteHistoryItem(id: entry.id)

    #expect(result)
    #expect(watcher.startCallCount == 1)
    #expect(watcher.writtenTexts == ["alpha"])
    #expect(pastePerformer.pasteCallCount == 1)
  }

  @Test
  func disablingShortClipStopsClipboardCaptureUntilReenabled() {
    let watcher = TestPasteboardWatcher()
    var onCopiedText: ((String) -> Void)?
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    let appState = AppState(
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { copiedTextHandler, _ in
        onCopiedText = copiedTextHandler
        return watcher
      },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    appState.setShortClipEnabled(false)
    onCopiedText?("ignored")

    #expect(appState.isShortClipEnabled == false)
    #expect(watcher.stopCallCount == 1)
    #expect(appState.history.isEmpty)

    appState.setShortClipEnabled(true)
    onCopiedText?("captured")

    #expect(appState.isShortClipEnabled)
    #expect(watcher.startCallCount == 2)
    #expect(appState.history.map(\.text) == ["captured"])
  }

  @Test
  func disablingShortClipBlocksQuickPasteActions() {
    let entry = ClipboardEntry(
      id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
      text: "blocked",
      copiedAt: Date(timeIntervalSince1970: 9_000)
    )
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    let appState = AppState(
      historyStore: ClipboardHistoryStore(history: [entry]),
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    appState.setShortClipEnabled(false)
    let result = appState.quickPasteHistoryItem(id: entry.id)

    #expect(!result)
    #expect(watcher.writtenTexts.isEmpty)
    #expect(pastePerformer.pasteCallCount == 0)
  }

  @Test
  func quickPasteStillCopiesWhenAutoPasteNeedsPermission() {
    let entry = ClipboardEntry(
      id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
      text: "beta",
      copiedAt: Date(timeIntervalSince1970: 2_000)
    )
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: false,
      pasteResult: false
    )
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    let appState = AppState(
      historyStore: ClipboardHistoryStore(
        history: [entry],
        now: { Date(timeIntervalSince1970: 2_100) }
      ),
      snippetStore: SnippetStore(),
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    let result = appState.quickPasteHistoryItem(id: entry.id)

    #expect(!result)
    #expect(watcher.writtenTexts == ["beta"])
    #expect(pastePerformer.permissionRequestCount == 0)
  }

  @Test
  func explicitPermissionRequestStillPromptsAccessibilityAccess() {
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: false,
      pasteResult: false
    )
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    let appState = AppState(
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    appState.requestAutoPastePermission()

    #expect(pastePerformer.permissionRequestCount == 1)
  }

  @Test
  func quickPasteCopiesWithoutPastingWhenAutoPasteIsDisabled() {
    let entry = ClipboardEntry(
      id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
      text: "copy only",
      copiedAt: Date(timeIntervalSince1970: 4_000)
    )
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let preference = InMemoryAutoPastePreferencePersistence(
      isAutoPasteEnabled: false
    )
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    let appState = AppState(
      historyStore: ClipboardHistoryStore(
        history: [entry],
        now: { Date(timeIntervalSince1970: 4_100) }
      ),
      snippetStore: SnippetStore(),
      snippetPersistence: persistence,
      autoPastePreferencePersistence: preference,
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    let result = appState.quickPasteHistoryItem(id: entry.id)

    #expect(!result)
    #expect(appState.isAutoPasteEnabled == false)
    #expect(watcher.writtenTexts == ["copy only"])
    #expect(pastePerformer.pasteCallCount == 0)
    #expect(pastePerformer.permissionRequestCount == 0)
  }

  @Test
  func updatingAutoPastePreferencePersistsValue() {
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let preference = InMemoryAutoPastePreferencePersistence()
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    let appState = AppState(
      snippetPersistence: persistence,
      autoPastePreferencePersistence: preference,
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    appState.setAutoPasteEnabled(false)

    #expect(appState.isAutoPasteEnabled == false)
    #expect(preference.isAutoPasteEnabled == false)
  }

  @Test
  func clearHistoryEmptiesHistoryWithoutRemovingSnippets() {
    let entry = ClipboardEntry(
      id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
      text: "gamma",
      copiedAt: Date(timeIntervalSince1970: 3_000)
    )
    let snippet = SnippetEntry(
      id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
      title: "Keep",
      text: "snippet",
      updatedAt: Date(timeIntervalSince1970: 3_100)
    )
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    try? persistence.save(snippets: [snippet])
    let appState = AppState(
      historyStore: ClipboardHistoryStore(history: [entry]),
      snippetStore: SnippetStore(snippets: [snippet]),
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    appState.clearHistory()

    #expect(appState.history.isEmpty)
    #expect(appState.snippets.map(\.title) == ["Keep"])
  }

  @Test
  func deleteHistoryItemRemovesOnlyRequestedEntry() {
    let olderEntry = ClipboardEntry(
      id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      text: "older",
      copiedAt: Date(timeIntervalSince1970: 5_000)
    )
    let newerEntry = ClipboardEntry(
      id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
      text: "newer",
      copiedAt: Date(timeIntervalSince1970: 5_100)
    )
    let snippet = SnippetEntry(
      id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
      title: "Keep",
      text: "snippet",
      updatedAt: Date(timeIntervalSince1970: 5_200)
    )
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    try? persistence.save(snippets: [snippet])
    let appState = AppState(
      historyStore: ClipboardHistoryStore(
        history: [newerEntry, olderEntry],
        now: { Date(timeIntervalSince1970: 5_300) }
      ),
      snippetStore: SnippetStore(snippets: [snippet]),
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    appState.deleteHistoryItem(id: olderEntry.id)

    #expect(appState.history.map(\.text) == ["newer"])
    #expect(appState.snippets.map(\.title) == ["Keep"])
  }

  @Test
  func snippetStoreRemainsLockedAndBlocksMutationsWhenLoadFailsWithLockError() {
    let existingSnippet = SnippetEntry(
      id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
      title: "Existing",
      text: "value",
      updatedAt: Date(timeIntervalSince1970: 6_000)
    )
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("snippets.json")
    let persistence = SnippetPersistence(
      fileURL: fileURL,
      fileDecoder: { _ in
        throw AppStateLockError.keyUnavailable
      }
    )
    try? FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? Data("encrypted".utf8).write(to: fileURL, options: .atomic)
    let appState = AppState(
      snippetStore: SnippetStore(snippets: [existingSnippet]),
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    appState.saveSnippet(id: nil, title: "Blocked", text: "should-not-save")
    appState.deleteSnippet(id: existingSnippet.id)
    appState.recallSnippet(id: existingSnippet.id)

    #expect(appState.areSnippetsLocked)
    #expect(appState.snippets.map(\.title) == ["Existing"])
    #expect(watcher.writtenTexts.isEmpty)
  }

  @Test
  func retrySnippetUnlockLoadsPersistedSnippetsAfterLockedLaunch() throws {
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let logger = InMemoryDiagnosticLogger()
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("snippets.json")
    let storedSnippets = [
      SnippetEntry(
        id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
        title: "Unlocked",
        text: "value",
        updatedAt: Date(timeIntervalSince1970: 8_000)
      )
    ]
    let decoderState = ToggleableDecoderState(
      decodedData: try makeSnippetData(storedSnippets)
    )
    let persistence = SnippetPersistence(
      fileURL: fileURL,
      fileDecoder: { storedData in
        try decoderState.decode(storedData)
      }
    )
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("encrypted".utf8).write(to: fileURL, options: .atomic)
    let appState = AppState(
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: logger,
      localizer: AppLocalizer(language: .english)
    )

    #expect(appState.areSnippetsLocked)

    decoderState.shouldThrowLock = false
    appState.retrySnippetUnlock()

    #expect(!appState.areSnippetsLocked)
    #expect(!appState.areSnippetsUnavailable)
    #expect(appState.snippets.map(\.title) == ["Unlocked"])
    #expect(logger.messages.joined(separator: "\n").contains("snippet_reload_succeeded"))
  }

  @Test
  func snippetStoreBecomesUnavailableAndBlocksMutationsWhenLoadFailsWithNonLockError() {
    let existingSnippet = SnippetEntry(
      id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
      title: "Existing",
      text: "value",
      updatedAt: Date(timeIntervalSince1970: 7_000)
    )
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let logger = InMemoryDiagnosticLogger()
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("snippets.json")
    let persistence = SnippetPersistence(
      fileURL: fileURL,
      fileDecoder: { _ in
        throw AppStateCorruptError.decodeFailure
      }
    )
    try? FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? Data("encrypted".utf8).write(to: fileURL, options: .atomic)
    let appState = AppState(
      snippetStore: SnippetStore(snippets: [existingSnippet]),
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: logger,
      localizer: AppLocalizer(language: .english)
    )

    appState.saveSnippet(id: nil, title: "Blocked", text: "should-not-save")
    appState.deleteSnippet(id: existingSnippet.id)
    appState.recallSnippet(id: existingSnippet.id)

    #expect(appState.areSnippetsLocked == false)
    #expect(appState.areSnippetsUnavailable)
    #expect(appState.snippets.map(\.title) == ["Existing"])
    #expect(watcher.writtenTexts.isEmpty)
    #expect(logger.messages.joined(separator: "\n").contains("snippet_load_failed"))
    #expect(!logger.messages.joined(separator: "\n").contains("value"))
    #expect(!logger.messages.joined(separator: "\n").contains("should-not-save"))
  }

  @Test
  func settingsAppearanceTrackingAllowsFallbackDecisions() {
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let logger = InMemoryDiagnosticLogger()
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    let appState = AppState(
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: logger,
      localizer: AppLocalizer(language: .english)
    )

    let requestDate = appState.recordSettingsOpenRequest(source: "test")

    #expect(!appState.didSettingsAppear(after: requestDate))

    appState.recordSettingsViewAppeared()

    #expect(appState.didSettingsAppear(after: requestDate))
    #expect(logger.messages.joined(separator: "\n").contains("settings_view_appeared"))
  }

  @Test
  func unavailableSnippetStateKeepsDiagnosticPathVisible() {
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let logger = InMemoryDiagnosticLogger(
      fileURL: URL(filePath: "/tmp/shortclip-unavailable.log")
    )
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("snippets.json")
    let persistence = SnippetPersistence(
      fileURL: fileURL,
      fileDecoder: { _ in
        throw AppStateCorruptError.decodeFailure
      }
    )
    try? FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? Data("encrypted".utf8).write(to: fileURL, options: .atomic)
    let appState = AppState(
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: logger,
      localizer: AppLocalizer(language: .english)
    )

    #expect(appState.areSnippetsUnavailable)
    #expect(appState.diagnosticLogPath == "/tmp/shortclip-unavailable.log")
  }

  @Test
  func appBundlePathReflectsRunningBundle() {
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json")
    )
    let appState = AppState(
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: InMemoryDiagnosticLogger(),
      localizer: AppLocalizer(language: .english)
    )

    #expect(appState.appBundlePath == Bundle.main.bundlePath)
  }

  @Test
  func saveFailureMarksSnippetsUnavailable() {
    let watcher = TestPasteboardWatcher()
    let pastePerformer = TestPasteActionPerformer(
      canAutoPaste: true,
      pasteResult: true
    )
    let logger = InMemoryDiagnosticLogger()
    let persistence = SnippetPersistence(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("snippets.json"),
      fileEncoder: { _ in
        throw AppStateCorruptError.decodeFailure
      }
    )
    let appState = AppState(
      snippetPersistence: persistence,
      autoPastePreferencePersistence: InMemoryAutoPastePreferencePersistence(),
      pasteboardWatcherFactory: { _, _ in watcher },
      pasteActionPerformer: pastePerformer,
      diagnosticLogger: logger,
      localizer: AppLocalizer(language: .english)
    )

    appState.saveSnippet(id: nil, title: "Persist me", text: "value")

    #expect(appState.areSnippetsUnavailable)
    #expect(logger.messages.joined(separator: "\n").contains("snippet_persist_failed"))
  }
}

@MainActor
private final class TestPasteboardWatcher: PasteboardWatching {
  private(set) var startCallCount = 0
  private(set) var stopCallCount = 0
  private(set) var writtenTexts: [String] = []

  func start() {
    startCallCount += 1
  }

  func stop() {
    stopCallCount += 1
  }

  func write(text: String) {
    writtenTexts = writtenTexts + [text]
  }
}

private final class InMemoryAutoPastePreferencePersistence: AutoPastePreferencePersisting {
  var isAutoPasteEnabled: Bool

  init(isAutoPasteEnabled: Bool = true) {
    self.isAutoPasteEnabled = isAutoPasteEnabled
  }

  func load() -> Bool {
    isAutoPasteEnabled
  }

  func save(isEnabled: Bool) {
    isAutoPasteEnabled = isEnabled
  }
}

private final class InMemoryDiagnosticLogger: DiagnosticLogging, @unchecked Sendable {
  let fileURL: URL
  private(set) var messages: [String] = []

  init(fileURL: URL = URL(filePath: "/tmp/shortclip-test.log")) {
    self.fileURL = fileURL
  }

  func log(_ message: String) {
    messages = messages + [message]
  }
}

private enum AppStateLockError: SnippetPersistenceLockingError {
  case keyUnavailable
}

private enum AppStateCorruptError: Error {
  case decodeFailure
}

private final class ToggleableDecoderState: @unchecked Sendable {
  let decodedData: Data
  var shouldThrowLock = true

  init(decodedData: Data) {
    self.decodedData = decodedData
  }

  func decode(_ storedData: Data) throws -> Data {
    if shouldThrowLock {
      throw AppStateLockError.keyUnavailable
    }

    return decodedData
  }
}

private func makeSnippetData(_ snippets: [SnippetEntry]) throws -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  encoder.dateEncodingStrategy = .iso8601
  return try encoder.encode(snippets)
}

@MainActor
private final class TestPasteActionPerformer: PasteActionPerforming {
  let canAutoPaste: Bool
  private let pasteResult: Bool
  private(set) var pasteCallCount = 0
  private(set) var permissionRequestCount = 0

  init(
    canAutoPaste: Bool,
    pasteResult: Bool
  ) {
    self.canAutoPaste = canAutoPaste
    self.pasteResult = pasteResult
  }

  func paste() -> Bool {
    pasteCallCount += 1
    return pasteResult
  }

  func requestPermission() {
    permissionRequestCount += 1
  }
}
