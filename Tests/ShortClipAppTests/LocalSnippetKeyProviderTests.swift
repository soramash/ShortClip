import CryptoKit
import Foundation
import Testing
@testable import ShortClipApp

struct LocalSnippetKeyProviderTests {
  @Test
  func readsExistingLocalKeyWithoutProbingOtherAccounts() throws {
    let data = Data(repeating: 7, count: 32)
    let store = LocalKeyTestStore(secrets: ["snippet-encryption-key-local": data])
    let provider = LocalSnippetKeyProvider(secretStore: store)

    let key = try provider.keyForDecryption()

    #expect(key.withUnsafeBytes { Data($0) } == data)
    #expect(store.readAccounts == ["snippet-encryption-key-local"])
    #expect(store.savedAccount == nil)
  }

  @Test
  func ignoresLegacyKeyWhenLocalKeyIsMissing() {
    let store = LocalKeyTestStore(secrets: [
      "snippet-encryption-key": SymmetricKey(size: .bits256).dataRepresentation
    ])
    let provider = LocalSnippetKeyProvider(secretStore: store)

    #expect(throws: SnippetCryptoServiceError.keyUnavailable) {
      _ = try provider.keyForDecryption()
    }
    #expect(store.savedAccount == nil)
  }

  @Test
  func missingKeyCannotBeReplacedDuringDecryption() {
    let store = LocalKeyTestStore()
    let provider = LocalSnippetKeyProvider(secretStore: store)

    #expect(throws: SnippetCryptoServiceError.keyUnavailable) {
      _ = try provider.keyForDecryption()
    }
    #expect(store.savedData == nil)
  }

  @Test
  func invalidKeyLengthCannotBeUsedOrReplaced() {
    let store = LocalKeyTestStore(secrets: ["snippet-encryption-key-local": Data([1])])
    let provider = LocalSnippetKeyProvider(secretStore: store)

    #expect(throws: SnippetCryptoServiceError.keyUnavailable) {
      _ = try provider.keyForDecryption()
    }
    #expect(store.savedAccount == nil)
  }

  @Test
  func createsClassicKeyForNewSnippets() throws {
    let store = LocalKeyTestStore()
    let provider = LocalSnippetKeyProvider(secretStore: store)

    _ = try provider.keyForEncryption()

    #expect(store.savedData?.count == 32)
    #expect(store.savedAccount == "snippet-encryption-key-local")
  }
}

private final class LocalKeyTestStore: SecretStoring, @unchecked Sendable {
  var secrets: [String: Data]
  var readAccounts: [String] = []
  var savedAccount: String?
  var savedData: Data?

  init(secrets: [String: Data] = [:]) {
    self.secrets = secrets
  }

  func readSecret(service: String, account: String) throws -> Data? {
    readAccounts.append(account)
    return service == SnippetKeyAccounts.primaryService ? secrets[account] : nil
  }

  func createSecret(
    _ data: Data,
    service: String,
    account: String
  ) throws {
    savedAccount = account
    savedData = data
    secrets[account] = data
  }
}
