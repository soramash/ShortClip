import Foundation

public struct SnippetStore {
  public private(set) var snippets: [SnippetEntry]
  private let now: () -> Date

  public init(
    snippets: [SnippetEntry] = [],
    now: @escaping () -> Date = Date.init
  ) {
    self.snippets = snippets
    self.now = now
  }

  public func replacingSnippets(_ snippets: [SnippetEntry]) -> SnippetStore {
    SnippetStore(
      snippets: snippets,
      now: now
    )
  }

  public mutating func addSnippet(
    title: String,
    text: String
  ) -> SnippetEntry? {
    let normalizedTitle = Self.normalize(title: title)
    let normalizedText = Self.normalize(text: text)

    guard !normalizedTitle.isEmpty, !normalizedText.isEmpty else {
      return nil
    }

    let entry = SnippetEntry(
      title: normalizedTitle,
      text: text,
      updatedAt: now()
    )

    snippets = [entry] + snippets
    return entry
  }

  public mutating func updateSnippet(
    id: UUID,
    title: String,
    text: String
  ) -> SnippetEntry? {
    let normalizedTitle = Self.normalize(title: title)
    let normalizedText = Self.normalize(text: text)

    guard !normalizedTitle.isEmpty, !normalizedText.isEmpty else {
      return nil
    }

    guard let entry = snippets.first(where: { $0.id == id }) else {
      return nil
    }

    let updatedEntry = entry.updated(
      title: normalizedTitle,
      text: text,
      at: now()
    )

    snippets = [updatedEntry] + snippets.filter { $0.id != id }
    return updatedEntry
  }

  public mutating func deleteSnippet(id: UUID) {
    snippets = snippets.filter { $0.id != id }
  }

  public mutating func recall(id: UUID) -> SnippetEntry? {
    guard let entry = snippets.first(where: { $0.id == id }) else {
      return nil
    }

    let recalledEntry = entry.updated(
      title: entry.title,
      text: entry.text,
      at: now()
    )

    snippets = [recalledEntry] + snippets.filter { $0.id != id }
    return recalledEntry
  }

  private static func normalize(title: String) -> String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func normalize(text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
