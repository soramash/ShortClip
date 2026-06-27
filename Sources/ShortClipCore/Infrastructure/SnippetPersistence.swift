import Foundation

public protocol SnippetPersistenceLockingError: Error {}

public enum SnippetPersistenceLoadError: Error, Equatable {
  case locked
}

public struct SnippetPersistence {
  public typealias FileEncoder = @Sendable (Data) throws -> Data
  public typealias FileDecoder = @Sendable (Data) throws -> Data
  public typealias Logger = @Sendable (String) -> Void

  public let fileURL: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let backupFileURL: URL
  private let fileEncoder: FileEncoder?
  private let fileDecoder: FileDecoder?
  private let logger: Logger?

  public init(
    fileURL: URL,
    fileManager: FileManager = .default,
    encoder: JSONEncoder? = nil,
    decoder: JSONDecoder? = nil,
    fileEncoder: FileEncoder? = nil,
    fileDecoder: FileDecoder? = nil,
    logger: Logger? = nil
  ) {
    self.fileURL = fileURL
    self.fileManager = fileManager
    self.encoder = encoder ?? SnippetPersistence.makeEncoder()
    self.decoder = decoder ?? SnippetPersistence.makeDecoder()
    self.backupFileURL = fileURL
      .deletingPathExtension()
      .appendingPathExtension("backup.json")
    self.fileEncoder = fileEncoder
    self.fileDecoder = fileDecoder
    self.logger = logger
  }

  public func load() throws -> [SnippetEntry] {
    let candidateURLs = [fileURL, backupFileURL].filter {
      fileManager.fileExists(atPath: $0.fileSystemPath)
    }

    guard !candidateURLs.isEmpty else {
      logger?("snippet_persistence_load_missing path=\(fileURL.fileSystemPath)")
      return []
    }

    var lastError: Error?

    for candidateURL in candidateURLs {
      do {
        logger?("snippet_persistence_load_attempt path=\(candidateURL.fileSystemPath)")
        let snippets = try loadSnippets(from: candidateURL)

        if candidateURL != fileURL {
          logger?("snippet_persistence_backup_restore path=\(candidateURL.fileSystemPath)")
          try save(snippets: snippets)
        }

        return snippets
      } catch {
        if let loadError = error as? SnippetPersistenceLoadError, loadError == .locked {
          logger?("snippet_persistence_load_locked path=\(candidateURL.fileSystemPath)")
          throw loadError
        }

        logger?(
          "snippet_persistence_load_failed path=\(candidateURL.fileSystemPath) error=\(String(describing: error))"
        )
        lastError = error
      }
    }

    throw lastError ?? CocoaError(.fileReadCorruptFile)
  }

  public func save(snippets: [SnippetEntry]) throws {
    let directoryURL = fileURL.deletingLastPathComponent()

    try fileManager.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )

    let data = try encoder.encode(snippets)
    let storedData = try fileEncoder?(data) ?? data

    try storedData.write(to: fileURL, options: .atomic)
    try storedData.write(to: backupFileURL, options: .atomic)
    logger?("snippet_persistence_save_succeeded count=\(snippets.count) bytes=\(storedData.count)")
  }

  private static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  private func loadSnippets(from fileURL: URL) throws -> [SnippetEntry] {
    let storedData = try Data(contentsOf: fileURL)
    logger?("snippet_persistence_read path=\(fileURL.fileSystemPath) bytes=\(storedData.count)")

    if let snippets = try? decodeSnippetPayload(from: storedData) {
      if fileEncoder != nil {
        logger?("snippet_persistence_plaintext_detected path=\(fileURL.fileSystemPath)")
        try save(snippets: snippets)
      }
      return snippets
    }

    if let fileDecoder {
      let decodedData: Data

      do {
        decodedData = try fileDecoder(storedData)
      } catch is SnippetPersistenceLockingError {
        logger?("snippet_persistence_decoder_locked path=\(fileURL.fileSystemPath)")
        throw SnippetPersistenceLoadError.locked
      }

      return try decodeSnippetPayload(from: decodedData)
    }

    throw CocoaError(.fileReadCorruptFile)
  }

  private func decodeSnippetPayload(from data: Data) throws -> [SnippetEntry] {
    if let snippets = try? decoder.decode([SnippetEntry].self, from: data) {
      return snippets
    }

    if let document = try? decoder.decode(SnippetDocument.self, from: data) {
      return document.snippets
    }

    throw CocoaError(.fileReadCorruptFile)
  }
}

private struct SnippetDocument: Decodable {
  let snippets: [SnippetEntry]
}

private extension URL {
  var fileSystemPath: String {
    path(percentEncoded: false)
  }
}
