import Carbon.HIToolbox
import Foundation
import Testing
@testable import ShortClipApp

@MainActor
struct QuickPasteShortcutManagerTests {
  @Test
  func loadsPersistedShortcutOnStartup() {
    let persistedShortcut = QuickPasteShortcut(
      keyCode: UInt32(kVK_ANSI_C),
      modifiers: UInt32(cmdKey | optionKey)
    )
    let persistence = InMemoryQuickPasteShortcutPersistence(
      storedShortcut: persistedShortcut
    )
    let registrar = TestQuickPasteShortcutRegistrar(results: [true])

    let manager = QuickPasteShortcutManager(
      persistence: persistence,
      registrar: registrar
    )

    #expect(manager.activeShortcut == persistedShortcut)
    #expect(registrar.registeredShortcuts == [persistedShortcut])
  }

  @Test
  func persistsAndRegistersUpdatedShortcut() {
    let persistence = InMemoryQuickPasteShortcutPersistence()
    let registrar = TestQuickPasteShortcutRegistrar(results: [true, true])
    let manager = QuickPasteShortcutManager(
      persistence: persistence,
      registrar: registrar
    )
    let updatedShortcut = QuickPasteShortcut(
      keyCode: UInt32(kVK_ANSI_C),
      modifiers: UInt32(cmdKey | optionKey)
    )

    let result = manager.applyShortcut(updatedShortcut)

    #expect(result == .updated)
    #expect(manager.activeShortcut == updatedShortcut)
    #expect(persistence.storedShortcut == updatedShortcut)
    #expect(registrar.registeredShortcuts == [
      QuickPasteShortcut.defaultValue,
      updatedShortcut
    ])
  }

  @Test
  func keepsPreviousShortcutWhenRegistrationFails() {
    let persistence = InMemoryQuickPasteShortcutPersistence()
    let registrar = TestQuickPasteShortcutRegistrar(results: [true, false, true])
    let manager = QuickPasteShortcutManager(
      persistence: persistence,
      registrar: registrar
    )
    let failedShortcut = QuickPasteShortcut(
      keyCode: UInt32(kVK_ANSI_C),
      modifiers: UInt32(cmdKey | optionKey)
    )

    let result = manager.applyShortcut(failedShortcut)

    #expect(result == .registrationFailed)
    #expect(manager.activeShortcut == QuickPasteShortcut.defaultValue)
    #expect(persistence.storedShortcut == nil)
    #expect(registrar.registeredShortcuts == [
      QuickPasteShortcut.defaultValue,
      failedShortcut,
      QuickPasteShortcut.defaultValue
    ])
  }

  @Test
  func rejectsInvalidShortcutBeforeRegistration() {
    let persistence = InMemoryQuickPasteShortcutPersistence()
    let registrar = TestQuickPasteShortcutRegistrar(results: [true])
    let manager = QuickPasteShortcutManager(
      persistence: persistence,
      registrar: registrar
    )
    let invalidShortcut = QuickPasteShortcut(
      keyCode: UInt32(kVK_ANSI_V),
      modifiers: UInt32(shiftKey)
    )

    let result = manager.applyShortcut(invalidShortcut)

    #expect(result == .invalidShortcut)
    #expect(manager.activeShortcut == QuickPasteShortcut.defaultValue)
    #expect(persistence.storedShortcut == nil)
    #expect(registrar.registeredShortcuts == [QuickPasteShortcut.defaultValue])
  }
}

private final class InMemoryQuickPasteShortcutPersistence: QuickPasteShortcutPersisting {
  var storedShortcut: QuickPasteShortcut?

  init(storedShortcut: QuickPasteShortcut? = nil) {
    self.storedShortcut = storedShortcut
  }

  func load() -> QuickPasteShortcut? {
    storedShortcut
  }

  func save(shortcut: QuickPasteShortcut) {
    storedShortcut = shortcut
  }
}

private final class TestQuickPasteShortcutRegistrar: QuickPasteShortcutRegistering {
  private let results: [Bool]
  private(set) var registeredShortcuts: [QuickPasteShortcut] = []
  private var attemptIndex = 0

  init(results: [Bool]) {
    self.results = results
  }

  func register(shortcut: QuickPasteShortcut) -> Bool {
    registeredShortcuts = registeredShortcuts + [shortcut]
    let result = results[min(attemptIndex, results.count - 1)]
    attemptIndex += 1
    return result
  }
}
