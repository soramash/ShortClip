import CryptoKit
import Foundation

/// Uses the file-based login Keychain so local builds need no provisioning profile.
struct LocalSnippetKeyProvider: SnippetKeyProviding {
  static let localAccount = SnippetKeyAccounts.localAccount

  private let secretStore: any SecretStoring
  private let keyCache: SymmetricKeyCache
  private let logger: @Sendable (String) -> Void

  init(
    secretStore: any SecretStoring = KeychainSecretStore(),
    keyCache: SymmetricKeyCache = SymmetricKeyCache(),
    logger: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.secretStore = secretStore
    self.keyCache = keyCache
    self.logger = logger
  }

  func keyForEncryption() throws -> SymmetricKey {
    try resolveKey(createIfMissing: true)
  }

  func keyForDecryption() throws -> SymmetricKey {
    try resolveKey(createIfMissing: false)
  }

  private func resolveKey(createIfMissing: Bool) throws -> SymmetricKey {
    if let key = keyCache.load() {
      return key
    }

    do {
      if let data = try secretStore.readSecret(
        service: SnippetKeyAccounts.primaryService,
        account: Self.localAccount
      ) {
        logger("snippet_local_key_loaded source=local")
        return try cache(data)
      }

      guard createIfMissing else {
        throw SnippetCryptoServiceError.keyUnavailable
      }

      return try createKey()
    } catch let error as KeychainSecretStoreError where error.isKeyAccessFailure {
      throw SnippetCryptoServiceError.keyUnavailable
    }
  }

  private func createKey() throws -> SymmetricKey {
    let key = SymmetricKey(size: .bits256)
    try secretStore.createSecret(
      key.dataRepresentation,
      service: SnippetKeyAccounts.primaryService,
      account: Self.localAccount
    )
    keyCache.save(key)
    logger("snippet_local_key_created")
    return key
  }

  private func cache(_ data: Data) throws -> SymmetricKey {
    guard data.count == 32 else {
      throw SnippetCryptoServiceError.keyUnavailable
    }
    let key = SymmetricKey(data: data)
    keyCache.save(key)
    return key
  }

}
