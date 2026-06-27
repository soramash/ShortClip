import CryptoKit
import Foundation
import ShortClipCore

struct SnippetCryptoService {
  private let keyProvider: any SnippetKeyProviding
  private let logger: @Sendable (String) -> Void

  init(
    keyProvider: any SnippetKeyProviding = SnippetKeyProvider(),
    logger: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.keyProvider = keyProvider
    self.logger = logger
  }

  func encrypt(_ plaintext: Data) throws -> Data {
    let key = try keyProvider.keyForEncryption()
    let sealedBox = try AES.GCM.seal(plaintext, using: key)
    let payload = EncryptedSnippetPayload(
      version: 1,
      algorithm: "AES.GCM",
      combinedCiphertext: try sealedBox.combinedData()
    )
    logger("snippet_encrypt_succeeded bytes=\(plaintext.count)")
    return try JSONEncoder().encode(payload)
  }

  func decrypt(_ encryptedData: Data) throws -> Data {
    let payload = try JSONDecoder().decode(EncryptedSnippetPayload.self, from: encryptedData)
    let key = try keyProvider.keyForDecryption()
    let sealedBox = try AES.GCM.SealedBox(combined: payload.combinedCiphertext)
    let plaintext = try AES.GCM.open(sealedBox, using: key)
    logger("snippet_decrypt_succeeded bytes=\(plaintext.count)")
    return plaintext
  }

  var fileEncoder: SnippetPersistence.FileEncoder {
    encrypt
  }

  var fileDecoder: SnippetPersistence.FileDecoder {
    decrypt
  }
}

private struct EncryptedSnippetPayload: Codable {
  let version: Int
  let algorithm: String
  let combinedCiphertext: Data
}

private extension AES.GCM.SealedBox {
  func combinedData() throws -> Data {
    guard let combined else {
      throw SnippetCryptoServiceError.missingCombinedCiphertext
    }

    return combined
  }
}

enum SnippetCryptoServiceError: Error, SnippetPersistenceLockingError {
  case missingCombinedCiphertext
  case keyUnavailable
}
