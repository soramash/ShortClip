import Foundation
import Testing
@testable import ShortClipApp

struct SnippetPersistenceFactoryTests {
  @Test
  func migratesLegacySnippetFileIntoDefaultLocation() throws {
    let applicationSupportURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("ApplicationSupport", isDirectory: true)
    let legacyDirectoryURL = applicationSupportURL
      .appendingPathComponent("ShortClipApp", isDirectory: true)
    let legacyFileURL = legacyDirectoryURL.appendingPathComponent("snippets.json")
    let currentFileURL = applicationSupportURL
      .appendingPathComponent("ShortClip", isDirectory: true)
      .appendingPathComponent("snippets.json")
    let jsonData = """
    [
      {
        "id": "55555555-5555-5555-5555-555555555555",
        "title": "Migrated",
        "text": "snippet",
        "updatedAt": "1970-01-01T00:08:20Z"
      }
    ]
    """.data(using: .utf8)!

    try FileManager.default.createDirectory(at: legacyDirectoryURL, withIntermediateDirectories: true)
    try jsonData.write(to: legacyFileURL, options: .atomic)

    let persistence = SnippetPersistenceFactory.makeDefault(
      fileManager: .default,
      applicationSupportURL: applicationSupportURL
    )

    #expect(FileManager.default.fileExists(atPath: currentFileURL.path(percentEncoded: false)))
    #expect(persistence.fileURL == currentFileURL)
    let migratedData = try Data(contentsOf: currentFileURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let migratedEntries = try decoder.decode([MigratedSnippetEntry].self, from: migratedData)
    #expect(migratedEntries.map(\.title) == ["Migrated"])
  }
}

private struct MigratedSnippetEntry: Decodable {
  let title: String
}
