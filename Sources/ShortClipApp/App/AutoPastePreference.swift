import Foundation

protocol AutoPastePreferencePersisting: AnyObject {
  func load() -> Bool
  func save(isEnabled: Bool)
}

final class UserDefaultsAutoPastePreferencePersistence: AutoPastePreferencePersisting {
  private static let key = "autoPasteEnabled"
  private let defaults: UserDefaults

  init(
    defaults: UserDefaults = UserDefaults(
      suiteName: UserDefaultsQuickPasteShortcutPersistence.suiteName
    ) ?? .standard
  ) {
    self.defaults = defaults
  }

  func load() -> Bool {
    guard defaults.object(forKey: Self.key) != nil else {
      return true
    }

    return defaults.bool(forKey: Self.key)
  }

  func save(isEnabled: Bool) {
    defaults.set(isEnabled, forKey: Self.key)
  }
}
