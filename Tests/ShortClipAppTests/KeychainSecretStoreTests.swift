import Foundation
import LocalAuthentication
import Security
import Testing
@testable import ShortClipApp

struct KeychainSecretStoreTests {
  @Test
  func readSecretUsesAuthenticationContextAndDataProtectionKeychain() throws {
    let session = KeychainAuthenticationSession(
      localizedReason: "Unlock snippet key"
    )
    let request = SecretAccessRequest(
      localizedReason: "Unlock snippet key",
      authenticationSession: session
    )
    let client = RecordingSecurityItemClient(
      copyResult: SecurityItemCopyResult(
        status: errSecSuccess,
        value: Data("secret".utf8)
      )
    )
    let store = KeychainSecretStore(securityClient: client)

    let secret = try store.readSecret(
      service: "dev.shortclip.snippet-encryption",
      account: "snippet-encryption-key-v2",
      request: request
    )

    #expect(secret == Data("secret".utf8))
    let query = try #require(client.lastCopyQuery)
    #expect((query[kSecUseDataProtectionKeychain] as? Bool) == true)
    let authenticationContext = try #require(query[kSecUseAuthenticationContext] as? LAContext)
    #expect(authenticationContext.localizedReason == "Unlock snippet key")
    #expect(authenticationContext.touchIDAuthenticationAllowableReuseDuration == KeychainAuthenticationSession.defaultReuseDuration)
  }

  @Test
  func saveSecretCreateOnlyUsesUserPresenceAccessControl() throws {
    let session = KeychainAuthenticationSession(
      localizedReason: "Unlock snippet key"
    )
    let request = SecretAccessRequest(
      localizedReason: "Unlock snippet key",
      authenticationSession: session
    )
    let client = RecordingSecurityItemClient()
    var recordedProtection: CFTypeRef?
    var recordedFlags: SecAccessControlCreateFlags?
    let store = KeychainSecretStore(
      securityClient: client,
      accessControlFactory: { protection, flags in
        recordedProtection = protection
        recordedFlags = flags
        var error: Unmanaged<CFError>?
        return try #require(
          SecAccessControlCreateWithFlags(nil, protection, flags, &error)
        )
      }
    )

    try store.saveSecret(
      Data("secret".utf8),
      service: "dev.shortclip.snippet-encryption",
      account: "snippet-encryption-key-v2",
      request: request,
      mode: .createOnly
    )

    let attributes = try #require(client.lastAddAttributes)
    #expect(attributes[kSecAttrAccessible] == nil)
    #expect(attributes[kSecAttrAccessControl] != nil)
    #expect(recordedProtection as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    #expect(recordedFlags == .userPresence)
    let authenticationContext = try #require(attributes[kSecUseAuthenticationContext] as? LAContext)
    #expect(authenticationContext.localizedReason == "Unlock snippet key")
  }

  @Test
  func saveSecretUpdateOrCreateFallsBackToAddWhenUpdateMisses() throws {
    let session = KeychainAuthenticationSession(
      localizedReason: "Unlock snippet key"
    )
    let request = SecretAccessRequest(
      localizedReason: "Unlock snippet key",
      authenticationSession: session
    )
    let client = RecordingSecurityItemClient(
      updateStatus: errSecItemNotFound,
      addStatus: errSecSuccess
    )
    let store = KeychainSecretStore(securityClient: client)

    try store.saveSecret(
      Data("secret".utf8),
      service: "dev.shortclip.snippet-encryption",
      account: "snippet-encryption-key-v2",
      request: request,
      mode: .updateOrCreate
    )

    #expect(client.updateCallCount == 1)
    #expect(client.addCallCount == 1)
  }
}

private final class RecordingSecurityItemClient: SecurityItemControlling, @unchecked Sendable {
  private let copyResult: SecurityItemCopyResult
  private let updateStatus: OSStatus
  private let addStatus: OSStatus
  private(set) var lastCopyQuery: [CFString: Any]?
  private(set) var lastUpdateQuery: [CFString: Any]?
  private(set) var lastUpdateAttributes: [CFString: Any]?
  private(set) var lastAddAttributes: [CFString: Any]?
  private(set) var updateCallCount = 0
  private(set) var addCallCount = 0

  init(
    copyResult: SecurityItemCopyResult = SecurityItemCopyResult(
      status: errSecItemNotFound,
      value: nil
    ),
    updateStatus: OSStatus = errSecSuccess,
    addStatus: OSStatus = errSecSuccess
  ) {
    self.copyResult = copyResult
    self.updateStatus = updateStatus
    self.addStatus = addStatus
  }

  func copyMatching(_ query: [CFString: Any]) -> SecurityItemCopyResult {
    lastCopyQuery = query
    return copyResult
  }

  func update(
    _ query: [CFString: Any],
    attributes: [CFString: Any]
  ) -> OSStatus {
    lastUpdateQuery = query
    lastUpdateAttributes = attributes
    updateCallCount += 1
    return updateStatus
  }

  func add(_ attributes: [CFString: Any]) -> OSStatus {
    lastAddAttributes = attributes
    addCallCount += 1
    return addStatus
  }
}
