import CryptoKit
import Foundation
import Testing
@testable import ShortClipApp

struct SnippetCryptoServiceTests {
  @Test
  func encryptsAndDecryptsSnippetPayload() throws {
    let key = SymmetricKey(size: .bits256)
    let provider = RecordingKeyProvider(
      encryptionKey: key,
      decryptionKey: key
    )
    let service = SnippetCryptoService(keyProvider: provider)
    let plaintext = Data("sensitive snippet payload".utf8)

    let encryptedData = try service.encrypt(plaintext)
    let decryptedData = try service.decrypt(encryptedData)

    #expect(encryptedData != plaintext)
    #expect(decryptedData == plaintext)
    #expect(provider.encryptionCallCount == 1)
    #expect(provider.decryptionCallCount == 1)
  }

  @Test
  func fileDecoderThenFileEncoderUsesProviderForEachOperation() throws {
    let key = SymmetricKey(size: .bits256)
    let bootstrapProvider = RecordingKeyProvider(
      encryptionKey: key,
      decryptionKey: key
    )
    let bootstrapService = SnippetCryptoService(keyProvider: bootstrapProvider)
    let plaintext = Data("codec-cache".utf8)
    let encodedPayload = try bootstrapService.fileEncoder(plaintext)
    let provider = RecordingKeyProvider(
      encryptionKey: key,
      decryptionKey: key
    )
    let service = SnippetCryptoService(keyProvider: provider)

    let decodedPayload = try service.fileDecoder(encodedPayload)
    let reencodedPayload = try service.fileEncoder(decodedPayload)

    #expect(decodedPayload == plaintext)
    #expect(reencodedPayload != plaintext)
    #expect(provider.decryptionCallCount == 1)
    #expect(provider.encryptionCallCount == 1)
  }

  @Test
  func decryptPropagatesKeyUnavailableError() throws {
    let key = SymmetricKey(size: .bits256)
    let bootstrapProvider = RecordingKeyProvider(
      encryptionKey: key,
      decryptionKey: key
    )
    let bootstrapService = SnippetCryptoService(keyProvider: bootstrapProvider)
    let encryptedData = try bootstrapService.encrypt(Data("cannot-decrypt-without-key".utf8))
    let failingProvider = RecordingKeyProvider(
      encryptionKey: key,
      decryptionKey: key,
      decryptionError: SnippetCryptoServiceError.keyUnavailable
    )
    let service = SnippetCryptoService(keyProvider: failingProvider)

    #expect(throws: SnippetCryptoServiceError.keyUnavailable) {
      _ = try service.decrypt(encryptedData)
    }
    #expect(failingProvider.decryptionCallCount == 1)
  }
}

private final class RecordingKeyProvider: SnippetKeyProviding, @unchecked Sendable {
  private let encryptionKey: SymmetricKey
  private let decryptionKey: SymmetricKey
  private let encryptionError: Error?
  private let decryptionError: Error?

  private(set) var encryptionCallCount = 0
  private(set) var decryptionCallCount = 0

  init(
    encryptionKey: SymmetricKey,
    decryptionKey: SymmetricKey,
    encryptionError: Error? = nil,
    decryptionError: Error? = nil
  ) {
    self.encryptionKey = encryptionKey
    self.decryptionKey = decryptionKey
    self.encryptionError = encryptionError
    self.decryptionError = decryptionError
  }

  func keyForEncryption() throws -> SymmetricKey {
    encryptionCallCount += 1
    if let encryptionError {
      throw encryptionError
    }
    return encryptionKey
  }

  func keyForDecryption() throws -> SymmetricKey {
    decryptionCallCount += 1
    if let decryptionError {
      throw decryptionError
    }
    return decryptionKey
  }
}
