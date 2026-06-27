import Foundation
import LocalAuthentication
import Security

enum SecretSaveMode: Equatable, Sendable {
  case updateOrCreate
  case createOnly
}

final class KeychainAuthenticationSession: @unchecked Sendable {
  static let defaultReuseDuration: TimeInterval = 10

  let contextObject: LAContext

  init(
    localizedReason: String,
    reuseDuration: TimeInterval = defaultReuseDuration
  ) {
    let context = LAContext()
    context.localizedReason = localizedReason
    context.touchIDAuthenticationAllowableReuseDuration = reuseDuration
    self.contextObject = context
  }
}

struct SecretAccessRequest: Sendable {
  let localizedReason: String
  let authenticationSession: KeychainAuthenticationSession?
  let useDataProtectionKeychain: Bool
  let flowID: String?

  init(
    localizedReason: String,
    authenticationSession: KeychainAuthenticationSession? = nil,
    useDataProtectionKeychain: Bool = true,
    flowID: String? = nil
  ) {
    self.localizedReason = localizedReason
    self.authenticationSession = authenticationSession
    self.useDataProtectionKeychain = useDataProtectionKeychain
    self.flowID = flowID
  }
}

struct SecurityItemCopyResult {
  let status: OSStatus
  let value: Any?
}

protocol SecurityItemControlling: Sendable {
  func copyMatching(_ query: [CFString: Any]) -> SecurityItemCopyResult
  func update(_ query: [CFString: Any], attributes: [CFString: Any]) -> OSStatus
  func add(_ attributes: [CFString: Any]) -> OSStatus
}

struct SystemSecurityItemClient: SecurityItemControlling {
  func copyMatching(_ query: [CFString: Any]) -> SecurityItemCopyResult {
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    return SecurityItemCopyResult(status: status, value: result)
  }

  func update(_ query: [CFString: Any], attributes: [CFString: Any]) -> OSStatus {
    SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
  }

  func add(_ attributes: [CFString: Any]) -> OSStatus {
    SecItemAdd(attributes as CFDictionary, nil)
  }
}

typealias KeychainAccessControlFactory = (
  CFTypeRef,
  SecAccessControlCreateFlags
) throws -> SecAccessControl

protocol SecretStoring: Sendable {
  func readSecret(
    service: String,
    account: String,
    request: SecretAccessRequest
  ) throws -> Data?

  func saveSecret(
    _ data: Data,
    service: String,
    account: String,
    request: SecretAccessRequest,
    mode: SecretSaveMode
  ) throws
}

struct KeychainSecretStore: SecretStoring, @unchecked Sendable {
  private let securityClient: any SecurityItemControlling
  private let accessControlFactory: KeychainAccessControlFactory
  private let logger: @Sendable (String) -> Void

  init(
    securityClient: any SecurityItemControlling = SystemSecurityItemClient(),
    accessControlFactory: @escaping KeychainAccessControlFactory = KeychainSecretStore.makeAccessControl,
    logger: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.securityClient = securityClient
    self.accessControlFactory = accessControlFactory
    self.logger = logger
  }

  func readSecret(
    service: String,
    account: String,
    request: SecretAccessRequest
  ) throws -> Data? {
    let query = makeReadQuery(
      service: service,
      account: account,
      request: request
    )
    let result = securityClient.copyMatching(query)
    logKeychainFlow(
      request: request,
      operation: "read",
      service: service,
      account: account,
      status: result.status
    )

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

  func saveSecret(
    _ data: Data,
    service: String,
    account: String,
    request: SecretAccessRequest,
    mode: SecretSaveMode
  ) throws {
    switch mode {
    case .updateOrCreate:
      try updateOrCreateSecret(
        data,
        service: service,
        account: account,
        request: request
      )
    case .createOnly:
      try addSecret(
        data,
        service: service,
        account: account,
        request: request
      )
    }
  }

  private func updateOrCreateSecret(
    _ data: Data,
    service: String,
    account: String,
    request: SecretAccessRequest
  ) throws {
    let query = makeBaseQuery(service: service, account: account, request: request)
    let attributes: [CFString: Any] = [
      kSecValueData: data
    ]
    let status = securityClient.update(query, attributes: attributes)
    logKeychainFlow(
      request: request,
      operation: "update",
      service: service,
      account: account,
      status: status
    )

    switch status {
    case errSecSuccess:
      return
    case errSecItemNotFound:
      try addSecret(
        data,
        service: service,
        account: account,
        request: request
      )
    default:
      throw KeychainSecretStoreError.unexpectedStatus(status)
    }
  }

  private func addSecret(
    _ data: Data,
    service: String,
    account: String,
    request: SecretAccessRequest
  ) throws {
    var attributes = makeBaseQuery(service: service, account: account, request: request)
    attributes[kSecValueData] = data
    attributes[kSecAttrAccessControl] = try accessControlFactory(
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      .userPresence
    )

    let status = securityClient.add(attributes)
    logKeychainFlow(
      request: request,
      operation: "add",
      service: service,
      account: account,
      status: status
    )

    switch status {
    case errSecSuccess, errSecDuplicateItem:
      return
    default:
      throw KeychainSecretStoreError.unexpectedStatus(status)
    }
  }

  private func makeBaseQuery(
    service: String,
    account: String,
    request: SecretAccessRequest
  ) -> [CFString: Any] {
    var query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account
    ]
    applyAuthentication(request: request, to: &query)
    return query
  }

  private func makeReadQuery(
    service: String,
    account: String,
    request: SecretAccessRequest
  ) -> [CFString: Any] {
    var query = makeBaseQuery(service: service, account: account, request: request)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    return query
  }

  private func applyAuthentication(
    request: SecretAccessRequest,
    to query: inout [CFString: Any]
  ) {
    if request.useDataProtectionKeychain {
      query[kSecUseDataProtectionKeychain] = true
    }

    guard let session = request.authenticationSession else {
      return
    }

    query[kSecUseAuthenticationContext] = session.contextObject
  }

  private func logKeychainFlow(
    request: SecretAccessRequest,
    operation: String,
    service: String,
    account: String,
    status: OSStatus
  ) {
    logger(
      [
        "keychain_flow",
        "flow_id=\(request.flowID ?? "none")",
        "operation=\(operation)",
        "service=\(service)",
        "account_version=\(accountVersion(for: service, account: account))",
        "used_auth_session=\(request.authenticationSession != nil)",
        "use_data_protection_keychain=\(request.useDataProtectionKeychain)",
        "used_cached_key=false",
        "osstatus=\(status)",
        "migration_result=none"
      ].joined(separator: " ")
    )
  }

  private func accountVersion(for service: String, account: String) -> String {
    if account.hasSuffix("-v2") {
      return "v2"
    }

    if service == SnippetKeyProvider.defaultPrimaryService {
      return "v1"
    }

    return "legacy"
  }

  private static func makeAccessControl(
    protection: CFTypeRef,
    flags: SecAccessControlCreateFlags
  ) throws -> SecAccessControl {
    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(nil, protection, flags, &error) else {
      throw KeychainSecretStoreError.accessControlCreationFailed(
        message: error?.takeRetainedValue().localizedDescription
      )
    }

    return accessControl
  }
}

enum KeychainSecretStoreError: Error {
  case invalidSecretData
  case unexpectedStatus(OSStatus)
  case accessControlCreationFailed(message: String?)

  var isKeyAccessFailure: Bool {
    switch self {
    case let .unexpectedStatus(status):
      [
        errSecAuthFailed,
        errSecInteractionNotAllowed,
        errSecUserCanceled,
        errSecNotAvailable
      ].contains(status)
    case .invalidSecretData, .accessControlCreationFailed:
      false
    }
  }

  var statusDescription: String {
    switch self {
    case .invalidSecretData:
      "invalid_secret_data"
    case let .unexpectedStatus(status):
      "\(status)"
    case let .accessControlCreationFailed(message):
      message ?? "access_control_creation_failed"
    }
  }
}
