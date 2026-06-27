import Foundation
import Testing
@testable import ShortClipCore

struct SnippetPersistenceTests {
  @Test
  func savesAndLoadsSnippetsFromJSONFile() throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directoryURL.appendingPathComponent("snippets.json")
    let persistence = SnippetPersistence(fileURL: fileURL)
    let snippets = [
      SnippetEntry(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        title: "Greeting",
        text: "Hello",
        updatedAt: Date(timeIntervalSince1970: 100)
      ),
      SnippetEntry(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        title: "Signature",
        text: "Regards",
        updatedAt: Date(timeIntervalSince1970: 200)
      )
    ]

    try persistence.save(snippets: snippets)
    let loadedSnippets = try persistence.load()

    #expect(loadedSnippets == snippets)
    #expect(FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))
  }

  @Test
  func loadingMissingFileReturnsEmptySnippets() throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("snippets.json")
    let persistence = SnippetPersistence(fileURL: fileURL)

    let loadedSnippets = try persistence.load()

    #expect(loadedSnippets.isEmpty)
  }

  @Test
  func loadsLegacySnippetsWithoutTitle() throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directoryURL.appendingPathComponent("snippets.json")
    let persistence = SnippetPersistence(fileURL: fileURL)
    let legacyJSON = """
    [
      {
        "id": "33333333-3333-3333-3333-333333333333",
        "text": "Legacy command\\n--flag",
        "updatedAt": "1970-01-01T00:05:00Z"
      }
    ]
    """.data(using: .utf8)!

    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    try legacyJSON.write(to: fileURL, options: .atomic)

    let loadedSnippets = try persistence.load()

    #expect(loadedSnippets.count == 1)
    #expect(loadedSnippets.first?.title == "Legacy command")
    #expect(loadedSnippets.first?.text == "Legacy command\n--flag")
  }

  @Test
  func loadsBackupFileWhenPrimarySnippetFileIsInvalid() throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directoryURL.appendingPathComponent("snippets.json")
    let backupURL = directoryURL.appendingPathComponent("snippets.backup.json")
    let persistence = SnippetPersistence(fileURL: fileURL)
    let snippets = [
      SnippetEntry(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        title: "Recovered",
        text: "backup",
        updatedAt: Date(timeIntervalSince1970: 400)
      )
    ]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(to: fileURL, options: .atomic)
    try encoder.encode(snippets).write(to: backupURL, options: .atomic)

    let loadedSnippets = try persistence.load()

    #expect(loadedSnippets == snippets)
  }

  @Test
  func savesAndLoadsSnippetsThroughFileCodec() throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directoryURL.appendingPathComponent("snippets.json")
    let persistence = SnippetPersistence(
      fileURL: fileURL,
      fileEncoder: { plaintext in
        Data("wrapped:".utf8) + plaintext
      },
      fileDecoder: { storedData in
        Data(storedData.dropFirst("wrapped:".count))
      }
    )
    let snippets = [
      SnippetEntry(
        id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
        title: "Encrypted",
        text: "secret",
        updatedAt: Date(timeIntervalSince1970: 600)
      )
    ]

    try persistence.save(snippets: snippets)

    let storedData = try Data(contentsOf: fileURL)
    let loadedSnippets = try persistence.load()

    #expect(String(decoding: storedData, as: UTF8.self).hasPrefix("wrapped:"))
    #expect(loadedSnippets == snippets)
  }

  @Test
  func loadingPlaintextFileWithCodecMigratesItToEncodedStorage() throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directoryURL.appendingPathComponent("snippets.json")
    let persistence = SnippetPersistence(
      fileURL: fileURL,
      fileEncoder: { plaintext in
        Data("wrapped:".utf8) + plaintext
      },
      fileDecoder: { storedData in
        Data(storedData.dropFirst("wrapped:".count))
      }
    )
    let snippets = [
      SnippetEntry(
        id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
        title: "Legacy",
        text: "plaintext",
        updatedAt: Date(timeIntervalSince1970: 700)
      )
    ]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    try encoder.encode(snippets).write(to: fileURL, options: .atomic)

    let loadedSnippets = try persistence.load()
    let storedData = try Data(contentsOf: fileURL)

    #expect(loadedSnippets == snippets)
    #expect(String(decoding: storedData, as: UTF8.self).hasPrefix("wrapped:"))
  }

  @Test
  func loadingEncryptedFileWithoutDecryptKeyThrowsLockedError() throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directoryURL.appendingPathComponent("snippets.json")
    let persistence = SnippetPersistence(
      fileURL: fileURL,
      fileDecoder: { _ in
        throw TestLockError.keyUnavailable
      }
    )

    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    try Data("encrypted-payload".utf8).write(to: fileURL, options: .atomic)
    let beforeData = try Data(contentsOf: fileURL)

    do {
      _ = try persistence.load()
      Issue.record("Expected locked error")
    } catch let error as SnippetPersistenceLoadError {
      #expect(error == .locked)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }

    let afterData = try Data(contentsOf: fileURL)
    #expect(afterData == beforeData)
  }
}

private enum TestLockError: SnippetPersistenceLockingError {
  case keyUnavailable
}
