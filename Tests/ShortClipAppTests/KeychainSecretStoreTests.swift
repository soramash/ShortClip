import Foundation
import Security
import Testing
@testable import ShortClipApp

struct KeychainSecretStoreTests {
  @Test
  func readsLocalKeyWithoutDataProtectionAuthentication() throws {
    let data = Data("secret".utf8)
    let client = RecordingSecurityItemClient(
      copyResult: SecurityItemCopyResult(status: errSecSuccess, value: data)
    )
    let store = KeychainSecretStore(securityClient: client)

    let loaded = try store.readSecret(
      service: SnippetKeyAccounts.primaryService,
      account: SnippetKeyAccounts.localAccount
    )

    #expect(loaded == data)
    let query = try #require(client.lastCopyQuery)
    #expect(query[kSecAttrService] as? String == SnippetKeyAccounts.primaryService)
    #expect(query[kSecAttrAccount] as? String == SnippetKeyAccounts.localAccount)
    #expect(query[kSecUseDataProtectionKeychain] == nil)
    #expect(query[kSecUseAuthenticationContext] == nil)
  }

  @Test
  func missingKeyReturnsNil() throws {
    let client = RecordingSecurityItemClient()
    let store = KeychainSecretStore(securityClient: client)

    let loaded = try store.readSecret(
      service: SnippetKeyAccounts.primaryService,
      account: SnippetKeyAccounts.localAccount
    )

    #expect(loaded == nil)
  }

  @Test
  func createsLocalKeyWithoutUserPresenceRequirement() throws {
    let client = RecordingSecurityItemClient()
    let store = KeychainSecretStore(securityClient: client)
    let data = Data("secret".utf8)

    try store.createSecret(
      data,
      service: SnippetKeyAccounts.primaryService,
      account: SnippetKeyAccounts.localAccount
    )

    let attributes = try #require(client.lastAddAttributes)
    #expect(attributes[kSecValueData] as? Data == data)
    #expect(attributes[kSecUseDataProtectionKeychain] == nil)
    #expect(attributes[kSecAttrAccessControl] == nil)
  }

  @Test
  func duplicateKeyIsNotSilentlyReplaced() {
    let client = RecordingSecurityItemClient(addStatus: errSecDuplicateItem)
    let store = KeychainSecretStore(securityClient: client)

    #expect(throws: KeychainSecretStoreError.self) {
      try store.createSecret(
        Data("new-key".utf8),
        service: SnippetKeyAccounts.primaryService,
        account: SnippetKeyAccounts.localAccount
      )
    }
  }
}

private final class RecordingSecurityItemClient: SecurityItemControlling, @unchecked Sendable {
  private let copyResult: SecurityItemCopyResult
  private let addStatus: OSStatus
  private(set) var lastCopyQuery: [CFString: Any]?
  private(set) var lastAddAttributes: [CFString: Any]?

  init(
    copyResult: SecurityItemCopyResult = SecurityItemCopyResult(
      status: errSecItemNotFound,
      value: nil
    ),
    addStatus: OSStatus = errSecSuccess
  ) {
    self.copyResult = copyResult
    self.addStatus = addStatus
  }

  func copyMatching(_ query: [CFString: Any]) -> SecurityItemCopyResult {
    lastCopyQuery = query
    return copyResult
  }

  func add(_ attributes: [CFString: Any]) -> OSStatus {
    lastAddAttributes = attributes
    return addStatus
  }
}
