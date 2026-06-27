import CryptoKit
import Foundation

protocol SnippetKeyProviding: Sendable {
  func keyForEncryption() throws -> SymmetricKey
  func keyForDecryption() throws -> SymmetricKey
}

struct SnippetKeyProvider: SnippetKeyProviding {
  static let defaultPrimaryService = "dev.shortclip.snippet-encryption"
  static let defaultLegacyServices = [
    "dev.shortclip.app"
  ]
  static let defaultV2Account = "snippet-encryption-key-v2"
  static let defaultV1Account = "snippet-encryption-key"
  static let defaultLocalizedReason = "Unlock ShortClip snippets"

  private let secretStore: any SecretStoring
  private let primaryService: String
  private let legacyServices: [String]
  private let v2Account: String
  private let v1Account: String
  private let keyCache: SymmetricKeyCache
  private let logger: @Sendable (String) -> Void

  init(
    secretStore: any SecretStoring = KeychainSecretStore(),
    primaryService: String = SnippetKeyProvider.defaultPrimaryService,
    legacyServices: [String] = SnippetKeyProvider.defaultLegacyServices,
    v2Account: String = SnippetKeyProvider.defaultV2Account,
    v1Account: String = SnippetKeyProvider.defaultV1Account,
    keyCache: SymmetricKeyCache = SymmetricKeyCache(),
    logger: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.secretStore = secretStore
    self.primaryService = primaryService
    self.legacyServices = legacyServices
    self.v2Account = v2Account
    self.v1Account = v1Account
    self.keyCache = keyCache
    self.logger = logger
  }

  func keyForEncryption() throws -> SymmetricKey {
    if let cachedKey = keyCache.load() {
      logCachedKey(flowID: nil)
      return cachedKey
    }

    let request = makeRequest()

    if let existingKey = try resolveExistingKey(request: request) {
      keyCache.save(existingKey)
      return existingKey
    }

    let newKey = SymmetricKey(size: .bits256)
    try savePrimaryV2Key(
      data: newKey.dataRepresentation,
      request: request,
      migrationResult: "created_v2"
    )
    keyCache.save(newKey)
    return newKey
  }

  func keyForDecryption() throws -> SymmetricKey {
    if let cachedKey = keyCache.load() {
      logCachedKey(flowID: nil)
      return cachedKey
    }

    let request = makeRequest()

    if let existingKey = try resolveExistingKey(request: request) {
      keyCache.save(existingKey)
      return existingKey
    }

    logger(
      makeLogLine(
        flowID: request.flowID,
        operation: "read",
        service: primaryService,
        accountVersion: "v2",
        usedAuthSession: request.authenticationSession != nil,
        usedCachedKey: false,
        osstatus: nil,
        migrationResult: "key_unavailable"
      )
    )
    throw SnippetCryptoServiceError.keyUnavailable
  }

  private func resolveExistingKey(
    request: SecretAccessRequest
  ) throws -> SymmetricKey? {
    if let v2KeyData = try readKeyData(
      service: primaryService,
      account: v2Account,
      accountVersion: "v2",
      request: request
    ) {
      return SymmetricKey(data: v2KeyData)
    }

    if let v1KeyData = try readKeyData(
      service: primaryService,
      account: v1Account,
      accountVersion: "v1",
      request: request,
      allowLegacyKeychainFallback: true
    ) {
      attemptBestEffortPrimaryV2Migration(
        data: v1KeyData,
        request: request,
        migrationResult: "migrated_v1_to_v2"
      )
      return SymmetricKey(data: v1KeyData)
    }

    for legacyService in legacyServices where legacyService != primaryService {
      if let legacyKeyData = try readKeyData(
        service: legacyService,
        account: v1Account,
        accountVersion: "legacy",
        request: request,
        allowLegacyKeychainFallback: true
      ) {
        attemptBestEffortPrimaryV2Migration(
          data: legacyKeyData,
          request: request,
          migrationResult: "migrated_legacy_to_v2"
        )
        return SymmetricKey(data: legacyKeyData)
      }
    }

    return nil
  }

  private func readKeyData(
    service: String,
    account: String,
    accountVersion: String,
    request: SecretAccessRequest,
    allowLegacyKeychainFallback: Bool = false
  ) throws -> Data? {
    if let keyData = try readKeyDataForRequest(
      service: service,
      account: account,
      accountVersion: accountVersion,
      request: request
    ) {
      return keyData
    }

    guard allowLegacyKeychainFallback, request.useDataProtectionKeychain else {
      return nil
    }

    let fallbackRequest = SecretAccessRequest(
      localizedReason: request.localizedReason,
      authenticationSession: request.authenticationSession,
      useDataProtectionKeychain: false,
      flowID: request.flowID
    )
    return try readKeyDataForRequest(
      service: service,
      account: account,
      accountVersion: accountVersion,
      request: fallbackRequest
    )
  }

  private func readKeyDataForRequest(
    service: String,
    account: String,
    accountVersion: String,
    request: SecretAccessRequest
  ) throws -> Data? {
    do {
      return try secretStore.readSecret(
        service: service,
        account: account,
        request: request
      )
    } catch let error as KeychainSecretStoreError {
      logger(
        makeLogLine(
          flowID: request.flowID,
          operation: "read",
          service: service,
          accountVersion: accountVersion,
          usedAuthSession: request.authenticationSession != nil,
          usedCachedKey: false,
          osstatus: error.osStatus,
          migrationResult: "read_failed"
        )
      )
      if error.isKeyAccessFailure {
        throw SnippetCryptoServiceError.keyUnavailable
      }
      throw error
    }
  }

  private func savePrimaryV2Key(
    data: Data,
    request: SecretAccessRequest,
    migrationResult: String
  ) throws {
    do {
      try secretStore.saveSecret(
        data,
        service: primaryService,
        account: v2Account,
        request: request,
        mode: .createOnly
      )
      logger(
        makeLogLine(
          flowID: request.flowID,
          operation: "add",
          service: primaryService,
          accountVersion: "v2",
          usedAuthSession: request.authenticationSession != nil,
          usedCachedKey: false,
          osstatus: errSecSuccess,
          migrationResult: migrationResult
        )
      )
    } catch let error as KeychainSecretStoreError {
      logger(
        makeLogLine(
          flowID: request.flowID,
          operation: "add",
          service: primaryService,
          accountVersion: "v2",
          usedAuthSession: request.authenticationSession != nil,
          usedCachedKey: false,
          osstatus: error.osStatus,
          migrationResult: "\(migrationResult)_failed"
        )
      )
      if error.isKeyAccessFailure {
        throw SnippetCryptoServiceError.keyUnavailable
      }
      throw error
    }
  }

  private func attemptBestEffortPrimaryV2Migration(
    data: Data,
    request: SecretAccessRequest,
    migrationResult: String
  ) {
    do {
      try secretStore.saveSecret(
        data,
        service: primaryService,
        account: v2Account,
        request: request,
        mode: .createOnly
      )
      logger(
        makeLogLine(
          flowID: request.flowID,
          operation: "add",
          service: primaryService,
          accountVersion: "v2",
          usedAuthSession: request.authenticationSession != nil,
          usedCachedKey: false,
          osstatus: errSecSuccess,
          migrationResult: migrationResult
        )
      )
    } catch let error as KeychainSecretStoreError {
      logger(
        makeLogLine(
          flowID: request.flowID,
          operation: "add",
          service: primaryService,
          accountVersion: "v2",
          usedAuthSession: request.authenticationSession != nil,
          usedCachedKey: false,
          osstatus: error.osStatus,
          migrationResult: "\(migrationResult)_skipped"
        )
      )
    } catch {
      logger(
        makeLogLine(
          flowID: request.flowID,
          operation: "add",
          service: primaryService,
          accountVersion: "v2",
          usedAuthSession: request.authenticationSession != nil,
          usedCachedKey: false,
          osstatus: nil,
          migrationResult: "\(migrationResult)_skipped_unknown_error"
        )
      )
    }
  }

  private func makeRequest() -> SecretAccessRequest {
    let flowID = UUID().uuidString
    return SecretAccessRequest(
      localizedReason: Self.defaultLocalizedReason,
      authenticationSession: KeychainAuthenticationSession(
        localizedReason: Self.defaultLocalizedReason
      ),
      flowID: flowID
    )
  }

  private func logCachedKey(flowID: String?) {
    logger(
      makeLogLine(
        flowID: flowID,
        operation: "read",
        service: primaryService,
        accountVersion: "cache",
        usedAuthSession: false,
        usedCachedKey: true,
        osstatus: errSecSuccess,
        migrationResult: "cache_hit"
      )
    )
  }

  private func makeLogLine(
    flowID: String?,
    operation: String,
    service: String,
    accountVersion: String,
    usedAuthSession: Bool,
    usedCachedKey: Bool,
    osstatus: OSStatus?,
    migrationResult: String
  ) -> String {
    [
      "snippet_key_flow",
      "flow_id=\(flowID ?? "none")",
      "operation=\(operation)",
      "service=\(service)",
      "account_version=\(accountVersion)",
      "used_auth_session=\(usedAuthSession)",
      "used_cached_key=\(usedCachedKey)",
      "osstatus=\(osstatus.map(String.init) ?? "none")",
      "migration_result=\(migrationResult)"
    ].joined(separator: " ")
  }
}

final class SymmetricKeyCache: @unchecked Sendable {
  private let lock = NSLock()
  private var keyData: Data?

  func load() -> SymmetricKey? {
    lock.lock()
    defer { lock.unlock() }

    guard let keyData else {
      return nil
    }

    return SymmetricKey(data: keyData)
  }

  func save(_ key: SymmetricKey) {
    let serializedKey = key.dataRepresentation
    lock.lock()
    keyData = serializedKey
    lock.unlock()
  }
}

extension SymmetricKey {
  var dataRepresentation: Data {
    withUnsafeBytes { Data($0) }
  }
}

private extension KeychainSecretStoreError {
  var osStatus: OSStatus? {
    switch self {
    case let .unexpectedStatus(status):
      status
    case .invalidSecretData, .accessControlCreationFailed:
      nil
    }
  }
}
