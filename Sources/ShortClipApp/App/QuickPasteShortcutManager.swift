import Foundation

enum QuickPasteShortcutApplyResult: Equatable {
  case updated
  case invalidShortcut
  case registrationFailed
}

protocol QuickPasteShortcutPersisting: AnyObject {
  func load() -> QuickPasteShortcut?
  func save(shortcut: QuickPasteShortcut)
}

protocol QuickPasteShortcutRegistering: AnyObject {
  func register(shortcut: QuickPasteShortcut) -> Bool
}

final class UserDefaultsQuickPasteShortcutPersistence: QuickPasteShortcutPersisting {
  static let suiteName = "dev.shortclip.settings"
  private static let shortcutKey = "quickPasteShortcut"

  private let defaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(defaults: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard) {
    self.defaults = defaults
  }

  func load() -> QuickPasteShortcut? {
    guard let data = defaults.data(forKey: Self.shortcutKey) else {
      return nil
    }

    return try? decoder.decode(QuickPasteShortcut.self, from: data)
  }

  func save(shortcut: QuickPasteShortcut) {
    guard let data = try? encoder.encode(shortcut) else {
      return
    }

    defaults.set(data, forKey: Self.shortcutKey)
  }
}

@MainActor
final class QuickPasteShortcutManager: ObservableObject {
  @Published private(set) var activeShortcut: QuickPasteShortcut

  private let persistence: QuickPasteShortcutPersisting
  private let registrar: QuickPasteShortcutRegistering

  init(
    persistence: QuickPasteShortcutPersisting = UserDefaultsQuickPasteShortcutPersistence(),
    registrar: QuickPasteShortcutRegistering
  ) {
    self.persistence = persistence
    self.registrar = registrar

    let persistedShortcut = persistence.load() ?? .defaultValue

    if registrar.register(shortcut: persistedShortcut) {
      activeShortcut = persistedShortcut
      return
    }

    _ = registrar.register(shortcut: .defaultValue)
    activeShortcut = .defaultValue
    if persistedShortcut != .defaultValue {
      persistence.save(shortcut: .defaultValue)
    }
  }

  @discardableResult
  func applyShortcut(_ shortcut: QuickPasteShortcut) -> QuickPasteShortcutApplyResult {
    guard shortcut.validationResult == .valid else {
      return .invalidShortcut
    }

    let previousShortcut = activeShortcut
    guard registrar.register(shortcut: shortcut) else {
      _ = registrar.register(shortcut: previousShortcut)
      return .registrationFailed
    }

    activeShortcut = shortcut
    persistence.save(shortcut: shortcut)
    return .updated
  }

  @discardableResult
  func restoreDefaultShortcut() -> QuickPasteShortcutApplyResult {
    applyShortcut(.defaultValue)
  }
}
