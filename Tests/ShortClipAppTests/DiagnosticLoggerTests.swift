import Foundation
import Testing
@testable import ShortClipApp

struct DiagnosticLoggerTests {
  @Test
  func defaultLogFileURLUsesShortClipLogsDirectory() {
    let applicationSupportURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)

    let fileURL = DiagnosticLoggerFactory.defaultLogFileURL(
      applicationSupportURL: applicationSupportURL
    )

    #expect(fileURL.path(percentEncoded: false).hasSuffix("Application Support/ShortClip/Logs/shortclip.log"))
  }

  @Test
  func appendsMessagesToLogFile() throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("shortclip.log")
    let logger = FileDiagnosticLogger(
      fileURL: fileURL,
      dateProvider: { Date(timeIntervalSince1970: 0) }
    )

    logger.log("settings_open_requested")
    logger.log("snippet_load_failed error=test")

    let contents = try String(contentsOf: fileURL, encoding: .utf8)

    #expect(contents.contains("settings_open_requested"))
    #expect(contents.contains("snippet_load_failed error=test"))
  }

  @Test
  func createsLogFileForNestedApplicationSupportPath() throws {
    let rootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)
    let fileURL = rootURL
      .appendingPathComponent("ShortClip", isDirectory: true)
      .appendingPathComponent("Logs", isDirectory: true)
      .appendingPathComponent("shortclip.log")
    let logger = FileDiagnosticLogger(
      fileURL: fileURL,
      dateProvider: { Date(timeIntervalSince1970: 1) }
    )

    logger.log("nested_log_created")

    #expect(FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))
    let contents = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(contents.contains("nested_log_created"))
  }
}
