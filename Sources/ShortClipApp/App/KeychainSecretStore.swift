import Foundation
import Security

struct SecurityItemCopyResult {
  let status: OSStatus
  let value: Any?
}

protocol SecurityItemControlling: Sendable {
  func copyMatching(_ query: [CFString: Any]) -> SecurityItemCopyResult
  func add(_ attributes: [CFString: Any]) -> OSStatus
}

struct SystemSecurityItemClient: SecurityItemControlling {
  func copyMatching(_ query: [CFString: Any]) -> SecurityItemCopyResult {
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    return SecurityItemCopyResult(status: status, value: result)
  }

  func add(_ attributes: [CFString: Any]) -> OSStatus {
    SecItemAdd(attributes as CFDictionary, nil)
  }
}

protocol SecretStoring: Sendable {
  func readSecret(service: String, account: String) throws -> Data?
  func createSecret(_ data: Data, service: String, account: String) throws
}

struct KeychainSecretStore: SecretStoring {
  private let securityClient: any SecurityItemControlling
  private let logger: @Sendable (String) -> Void

  init(
    securityClient: any SecurityItemControlling = SystemSecurityItemClient(),
    logger: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.securityClient = securityClient
    self.logger = logger
  }

  func readSecret(service: String, account: String) throws -> Data? {
    var query = makeBaseQuery(service: service, account: account)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    let result = securityClient.copyMatching(query)
    logger("keychain_flow operation=read osstatus=\(result.status)")

    switch result.status {
    case errSecSuccess:
      guard let data = result.value as? Data else {
        throw KeychainSecretStoreError.invalidSecretData
      }
      return data
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainSecretStoreError.unexpectedStatus(result.status)
    }
  }

  func createSecret(_ data: Data, service: String, account: String) throws {
    var attributes = makeBaseQuery(service: service, account: account)
    attributes[kSecValueData] = data
    let status = securityClient.add(attributes)
    logger("keychain_flow operation=add osstatus=\(status)")

    guard status == errSecSuccess else {
      throw KeychainSecretStoreError.unexpectedStatus(status)
    }
  }

  private func makeBaseQuery(service: String, account: String) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account
    ]
  }
}

enum KeychainSecretStoreError: Error {
  case invalidSecretData
  case unexpectedStatus(OSStatus)

  var isKeyAccessFailure: Bool {
    guard case let .unexpectedStatus(status) = self else {
      return false
    }
    return [
      errSecAuthFailed,
      errSecInteractionNotAllowed,
      errSecUserCanceled,
      errSecNotAvailable
    ].contains(status)
  }
}
