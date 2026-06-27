import Foundation

public struct SnippetEntry: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let title: String
  public let text: String
  public let updatedAt: Date

  public init(
    id: UUID = UUID(),
    title: String,
    text: String,
    updatedAt: Date
  ) {
    self.id = id
    self.title = title
    self.text = text
    self.updatedAt = updatedAt
  }

  public func updated(
    title: String,
    text: String,
    at date: Date
  ) -> SnippetEntry {
    SnippetEntry(
      id: id,
      title: title,
      text: text,
      updatedAt: date
    )
  }

  enum CodingKeys: String, CodingKey {
    case id
    case title
    case text
    case updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let text = try container.decode(String.self, forKey: .text)
    let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title)

    self.init(
      id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
      title: Self.resolvedTitle(title: decodedTitle, text: text),
      text: text,
      updatedAt: try Self.decodeUpdatedAt(from: container)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(title, forKey: .title)
    try container.encode(text, forKey: .text)
    try container.encode(updatedAt, forKey: .updatedAt)
  }

  private static func resolvedTitle(
    title: String?,
    text: String
  ) -> String {
    let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard trimmedTitle.isEmpty else {
      return trimmedTitle
    }

    let fallbackTitle = text
      .split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first(where: { !$0.isEmpty })

    return fallbackTitle ?? "Snippet"
  }

  private static func decodeUpdatedAt(
    from container: KeyedDecodingContainer<CodingKeys>
  ) throws -> Date {
    if let date = try container.decodeIfPresent(Date.self, forKey: .updatedAt) {
      return date
    }

    if let rawString = try container.decodeIfPresent(String.self, forKey: .updatedAt),
      let date = Self.decodeISO8601Date(from: rawString)
    {
      return date
    }

    if let rawSeconds = try container.decodeIfPresent(Double.self, forKey: .updatedAt) {
      return Date(timeIntervalSince1970: rawSeconds)
    }

    if let rawSeconds = try container.decodeIfPresent(Int.self, forKey: .updatedAt) {
      return Date(timeIntervalSince1970: TimeInterval(rawSeconds))
    }

    return Date(timeIntervalSince1970: 0)
  }

  private static func decodeISO8601Date(from rawString: String) -> Date? {
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    if let date = fractionalFormatter.date(from: rawString) {
      return date
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: rawString)
  }
}
