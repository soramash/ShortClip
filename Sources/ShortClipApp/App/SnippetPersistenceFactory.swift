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
    let keyProvider = LocalSnippetKeyProvider(
      secretStore: secretStore,
      keyCache: SymmetricKeyCache(),
      logger: resolvedDiagnosticLogger.log
    )
    let cryptoService = SnippetCryptoService(
      keyProvider: keyProvider,
      logger: resolvedDiagnosticLogger.log
    )

    return SnippetPersistence(
      fileURL: snippetsURL,
      fileEncoder: cryptoService.fileEncoder,
      fileDecoder: cryptoService.fileDecoder,
      logger: resolvedDiagnosticLogger.log
    )
  }
}

private extension URL {
  var fileSystemPath: String {
    path(percentEncoded: false)
  }
}
