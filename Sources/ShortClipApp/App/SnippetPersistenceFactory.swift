import Foundation
import ShortClipCore

enum SnippetPersistenceFactory {
  static func makeDefault(
    fileManager: FileManager = .default,
    applicationSupportURL: URL? = nil,
    diagnosticLogger: (any DiagnosticLogging)? = nil
  ) -> SnippetPersistence {
    let resolvedDiagnosticLogger =
      diagnosticLogger
      ?? DiagnosticLoggerFactory.makeDefault(
        fileManager: fileManager,
        applicationSupportURL: applicationSupportURL
      )
    let resolvedApplicationSupportURL =
      applicationSupportURL
      ?? (try? fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      ))
      ?? fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)

    let snippetsURL = resolvedApplicationSupportURL
      .appendingPathComponent("ShortClip", isDirectory: true)
      .appendingPathComponent("snippets.json")
    resolvedDiagnosticLogger.log("snippet_persistence_factory_path path=\(snippetsURL.fileSystemPath)")
    let secretStore = KeychainSecretStore(logger: resolvedDiagnosticLogger.log)
    let keyProvider = SnippetKeyProvider(
      secretStore: secretStore,
      keyCache: SymmetricKeyCache(),
      logger: resolvedDiagnosticLogger.log
    )
    let cryptoService = SnippetCryptoService(
      keyProvider: keyProvider,
      logger: resolvedDiagnosticLogger.log
    )

    migrateLegacySnippetsIfNeeded(
      fileManager: fileManager,
      applicationSupportURL: resolvedApplicationSupportURL,
      snippetsURL: snippetsURL,
      log: resolvedDiagnosticLogger.log
    )

    return SnippetPersistence(
      fileURL: snippetsURL,
      fileEncoder: cryptoService.fileEncoder,
      fileDecoder: cryptoService.fileDecoder,
      logger: resolvedDiagnosticLogger.log
    )
  }

  private static func migrateLegacySnippetsIfNeeded(
    fileManager: FileManager,
    applicationSupportURL: URL,
    snippetsURL: URL,
    log: @escaping @Sendable (String) -> Void
  ) {
    guard !fileManager.fileExists(atPath: snippetsURL.fileSystemPath) else {
      return
    }

    guard let legacyFileURL = legacySnippetFileURLs(applicationSupportURL: applicationSupportURL)
      .first(where: { fileManager.fileExists(atPath: $0.fileSystemPath) })
    else {
      return
    }

    do {
      try fileManager.createDirectory(
        at: snippetsURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try fileManager.copyItem(at: legacyFileURL, to: snippetsURL)
      log(
        "snippet_legacy_migration_succeeded from=\(legacyFileURL.fileSystemPath) to=\(snippetsURL.fileSystemPath)"
      )
    } catch {
      log(
        "snippet_legacy_migration_failed from=\(legacyFileURL.fileSystemPath) to=\(snippetsURL.fileSystemPath) error=\(String(describing: error))"
      )
    }
  }

  private static func legacySnippetFileURLs(
    applicationSupportURL: URL
  ) -> [URL] {
    [
      "ShortClipApp",
      "dev.shortclip.app"
    ].map {
      applicationSupportURL
        .appendingPathComponent($0, isDirectory: true)
        .appendingPathComponent("snippets.json")
    }
  }
}

private extension URL {
  var fileSystemPath: String {
    path(percentEncoded: false)
  }
}
