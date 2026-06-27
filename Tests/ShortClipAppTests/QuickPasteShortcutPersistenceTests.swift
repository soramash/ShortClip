import Carbon.HIToolbox
import Foundation
import Testing
@testable import ShortClipApp

struct QuickPasteShortcutPersistenceTests {
  @Test
  func savesAndLoadsShortcutFromFixedUserDefaultsSuite() {
    let suiteName = "dev.shortclip.settings.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let persistence = UserDefaultsQuickPasteShortcutPersistence(defaults: defaults)
    let shortcut = QuickPasteShortcut(
      keyCode: UInt32(kVK_ANSI_C),
      modifiers: UInt32(cmdKey | optionKey)
    )

    persistence.save(shortcut: shortcut)

    #expect(persistence.load() == shortcut)
  }

  @Test
  func usesFixedSuiteNameForUpgradeSafePreferences() {
    #expect(UserDefaultsQuickPasteShortcutPersistence.suiteName == "dev.shortclip.settings")
  }

  @Test
  func savesAndLoadsAutoPastePreferenceFromFixedUserDefaultsSuite() {
    let suiteName = "dev.shortclip.settings.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let persistence = UserDefaultsAutoPastePreferencePersistence(defaults: defaults)

    persistence.save(isEnabled: false)

    #expect(persistence.load() == false)
  }
}
