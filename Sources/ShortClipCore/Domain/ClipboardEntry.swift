import Foundation

public struct ClipboardEntry: Equatable, Identifiable, Sendable {
  public let id: UUID
  public let text: String
  public let copiedAt: Date

  public init(
    id: UUID = UUID(),
    text: String,
    copiedAt: Date
  ) {
    self.id = id
    self.text = text
    self.copiedAt = copiedAt
  }

  public func recalled(at date: Date) -> ClipboardEntry {
    ClipboardEntry(
      id: id,
      text: text,
      copiedAt: date
    )
  }
}
