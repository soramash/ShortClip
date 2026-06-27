import CryptoKit
import Foundation
import Testing
@testable import ShortClipApp

struct SnippetKeyProviderTests {
  @Test
  func encryptionReadsV2KeyOnlyWhenPresent() throws {
    let secretStore = RecordingSecretStore(
      secrets: [
        "dev.shortclip.snippet-encryption::snippet-encryption-key-v2": makeKeyData(fill: 1)
      ]
    )
    let provider = SnippetKeyProvider(
      secretStore: secretStore,
      primaryService: "dev.shortclip.snippet-encryption",
      legacyServices: ["dev.shortclip.app"],
      v2Account: "snippet-encryption-key-v2",
      v1Account: "snippet-encryption-key",
      keyCache: SymmetricKeyCache()
    )

    let key = try provider.keyForEncryption()

    #expect(serialize(key) == makeKeyData(fill: 1))
    #expect(secretStore.readRequests.map(\.compoundKey) == [
      "dev.shortclip.snippet-encryption::snippet-encryption-key-v2"
    ])
    #expect(secretStore.saveRequests.isEmpty)
  }

  @Test
  func decryptionMigratesPrimaryV1KeyToV2WithoutLegacyProbe() throws {
    let secretStore = RecordingSecretStore(
      legacyKeychainSecrets: [
        "dev.shortclip.snippet-encryption::snippet-encryption-key": makeKeyData(fill: 2)
      ]
    )
    let provider = SnippetKeyProvider(
      secretStore: secretStore,
      primaryService: "dev.shortclip.snippet-encryption",
      legacyServices: ["dev.shortclip.app"],
      v2Account: "snippet-encryption-key-v2",
      v1Account: "snippet-encryption-key",
      keyCache: SymmetricKeyCache()
    )

    let key = try provider.keyForDecryption()

    #expect(serialize(key) == makeKeyData(fill: 2))
    #expect(secretStore.readRequests.map(\.compoundKey) == [
      "dev.shortclip.snippet-encryption::snippet-encryption-key-v2",
      "dev.shortclip.snippet-encryption::snippet-encryption-key",
      "dev.shortclip.snippet-encryption::snippet-encryption-key"
    ])
    #expect(secretStore.readRequests.map(\.useDataProtectionKeychain) == [true, true, false])
    let saveRequest = try #require(secretStore.saveRequests.last)
    #expect(saveRequest.compoundKey == "dev.shortclip.snippet-encryption::snippet-encryption-key-v2")
    #expect(saveRequest.mode == .createOnly)
    #expect(saveRequest.useDataProtectionKeychain)
  }

  @Test
  func decryptionMigratesLegacyKeyToV2AndCachesResult() throws {
    let secretStore = RecordingSecretStore(
      legacyKeychainSecrets: [
        "dev.shortclip.app::snippet-encryption-key": makeKeyData(fill: 3)
      ]
    )
    let provider = SnippetKeyProvider(
      secretStore: secretStore,
      primaryService: "dev.shortclip.snippet-encryption",
      legacyServices: ["dev.shortclip.app"],
      v2Account: "snippet-encryption-key-v2",
      v1Account: "snippet-encryption-key",
      keyCache: SymmetricKeyCache()
    )

    let decryptedKey = try provider.keyForDecryption()
    let encryptedKey = try provider.keyForEncryption()

    #expect(serialize(decryptedKey) == makeKeyData(fill: 3))
    #expect(serialize(encryptedKey) == makeKeyData(fill: 3))
    #expect(secretStore.readRequests.map(\.compoundKey) == [
      "dev.shortclip.snippet-encryption::snippet-encryption-key-v2",
      "dev.shortclip.snippet-encryption::snippet-encryption-key",
      "dev.shortclip.snippet-encryption::snippet-encryption-key",
      "dev.shortclip.app::snippet-encryption-key",
      "dev.shortclip.app::snippet-encryption-key"
    ])
    #expect(secretStore.readRequests.map(\.useDataProtectionKeychain) == [true, true, false, true, false])
    #expect(secretStore.saveRequests.count == 1)
    #expect(secretStore.saveRequests.allSatisfy { $0.useDataProtectionKeychain })
  }

  @Test
  func decryptionStillSucceedsWhenMigrationToV2Fails() throws {
    let secretStore = RecordingSecretStore(
      legacyKeychainSecrets: [
        "dev.shortclip.snippet-encryption::snippet-encryption-key": makeKeyData(fill: 4)
      ],
      saveErrors: [
        "dev.shortclip.snippet-encryption::snippet-encryption-key-v2":
          KeychainSecretStoreError.unexpectedStatus(errSecMissingEntitlement)
      ]
    )
    let provider = SnippetKeyProvider(
      secretStore: secretStore,
      primaryService: "dev.shortclip.snippet-encryption",
      legacyServices: ["dev.shortclip.app"],
      v2Account: "snippet-encryption-key-v2",
      v1Account: "snippet-encryption-key",
      keyCache: SymmetricKeyCache()
    )

    let key = try provider.keyForDecryption()
    let encryptedKey = try provider.keyForEncryption()

    #expect(serialize(key) == makeKeyData(fill: 4))
    #expect(serialize(encryptedKey) == makeKeyData(fill: 4))
    #expect(secretStore.saveRequests.count == 1)
  }

  @Test
  func keyAccessFailureThrowsWithoutSaving() throws {
    let secretStore = RecordingSecretStore(
      readErrors: [
        "dev.shortclip.snippet-encryption::snippet-encryption-key-v2":
          KeychainSecretStoreError.unexpectedStatus(errSecAuthFailed)
      ]
    )
    let provider = SnippetKeyProvider(
      secretStore: secretStore,
      primaryService: "dev.shortclip.snippet-encryption",
      legacyServices: ["dev.shortclip.app"],
      v2Account: "snippet-encryption-key-v2",
      v1Account: "snippet-encryption-key",
      keyCache: SymmetricKeyCache()
    )

    #expect(throws: SnippetCryptoServiceError.keyUnavailable) {
      _ = try provider.keyForDecryption()
    }
    #expect(secretStore.saveRequests.isEmpty)
  }
}

private final class RecordingSecretStore: SecretStoring, @unchecked Sendable {
  struct ReadRequest: Equatable {
    let service: String
    let account: String
    let useDataProtectionKeychain: Bool

    var compoundKey: String {
      "\(service)::\(account)"
    }
  }

  struct SaveRequest: Equatable {
    let service: String
    let account: String
    let mode: SecretSaveMode
    let useDataProtectionKeychain: Bool

    var compoundKey: String {
      "\(service)::\(account)"
    }
  }

  private let readErrors: [String: Error]
  private let saveErrors: [String: Error]
  private(set) var secrets: [String: Data]
  private(set) var legacyKeychainSecrets: [String: Data]
  private(set) var readRequests: [ReadRequest] = []
  private(set) var saveRequests: [SaveRequest] = []

  init(
    secrets: [String: Data] = [:],
    legacyKeychainSecrets: [String: Data] = [:],
    readErrors: [String: Error] = [:],
    saveErrors: [String: Error] = [:]
  ) {
    self.secrets = secrets
    self.legacyKeychainSecrets = legacyKeychainSecrets
    self.readErrors = readErrors
    self.saveErrors = saveErrors
  }

  func readSecret(
    service: String,
    account: String,
    request: SecretAccessRequest
  ) throws -> Data? {
    let key = "\(service)::\(account)"
    readRequests += [
      ReadRequest(
        service: service,
        account: account,
        useDataProtectionKeychain: request.useDataProtectionKeychain
      )
    ]
    if let error = readErrors[key] {
      throw error
    }
    if request.useDataProtectionKeychain {
      return secrets[key]
    }

    return legacyKeychainSecrets[key]
  }

  func saveSecret(
    _ data: Data,
    service: String,
    account: String,
    request: SecretAccessRequest,
    mode: SecretSaveMode
  ) throws {
    let key = "\(service)::\(account)"
    saveRequests += [
      SaveRequest(
        service: service,
        account: account,
        mode: mode,
        useDataProtectionKeychain: request.useDataProtectionKeychain
      )
    ]
    if let error = saveErrors[key] {
      throw error
    }
    secrets[key] = data
  }
}

private func makeKeyData(fill: UInt8) -> Data {
  Data(repeating: fill, count: 32)
}

private func serialize(_ key: SymmetricKey) -> Data {
  key.withUnsafeBytes { Data($0) }
}
