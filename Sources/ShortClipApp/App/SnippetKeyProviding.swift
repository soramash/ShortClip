import CryptoKit
import Foundation

protocol SnippetKeyProviding: Sendable {
  func keyForEncryption() throws -> SymmetricKey
  func keyForDecryption() throws -> SymmetricKey
}

final class SymmetricKeyCache: @unchecked Sendable {
  private let lock = NSLock()
  private var keyData: Data?

  func load() -> SymmetricKey? {
    lock.lock()
    defer { lock.unlock() }
    return keyData.map(SymmetricKey.init(data:))
  }

  func save(_ key: SymmetricKey) {
    let data = key.dataRepresentation
    lock.lock()
    keyData = data
    lock.unlock()
  }
}

extension SymmetricKey {
  var dataRepresentation: Data {
    withUnsafeBytes { Data($0) }
  }
}
