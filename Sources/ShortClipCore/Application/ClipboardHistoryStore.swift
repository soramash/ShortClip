import Foundation

public struct ClipboardHistoryStore {
  public static let maximumEntryCount = 20
  public static let expirationInterval: TimeInterval = 60 * 60

  public private(set) var history: [ClipboardEntry]
  private let now: () -> Date

  public init(
    history: [ClipboardEntry] = [],
    now: @escaping () -> Date = Date.init
  ) {
    self.history = history
    self.now = now
  }

  public mutating func recordCopy(text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let timestamp = now()
    let activeHistory = Self.pruneExpiredEntries(
      from: history,
      now: timestamp
    )

    let entry = ClipboardEntry(
      text: text,
      copiedAt: timestamp
    )

    history = Self.limitEntries(
      [entry] + activeHistory.filter { $0.text != text }
    )
  }

  public mutating func recall(id: UUID) -> ClipboardEntry? {
    let timestamp = now()
    let activeHistory = Self.pruneExpiredEntries(
      from: history,
      now: timestamp
    )

    guard let entry = activeHistory.first(where: { $0.id == id }) else {
      history = activeHistory
      return nil
    }

    let refreshedEntry = entry.recalled(at: timestamp)
    history = Self.limitEntries(
      [refreshedEntry] + activeHistory.filter { $0.id != id }
    )

    return refreshedEntry
  }

  public mutating func pruneExpired() {
    history = Self.pruneExpiredEntries(
      from: history,
      now: now()
    )
  }

  public mutating func clear() {
    history = []
  }

  public mutating func delete(id: UUID) {
    history = history.filter { $0.id != id }
  }

  private static func pruneExpiredEntries(
    from history: [ClipboardEntry],
    now: Date
  ) -> [ClipboardEntry] {
    history.filter {
      now.timeIntervalSince($0.copiedAt) <= expirationInterval
    }
  }

  private static func limitEntries(
    _ entries: [ClipboardEntry]
  ) -> [ClipboardEntry] {
    Array(entries.prefix(maximumEntryCount))
  }
}
