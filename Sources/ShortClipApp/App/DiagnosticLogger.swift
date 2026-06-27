import Foundation
import OSLog

protocol DiagnosticLogging: Sendable {
  var fileURL: URL { get }
  func log(_ message: String)
}

final class FileDiagnosticLogger: DiagnosticLogging, @unchecked Sendable {
  static let maximumFileSizeBytes = 256 * 1024
  private static let fallbackLogger = Logger(
    subsystem: "dev.shortclip.app",
    category: "diagnostics"
  )

  let fileURL: URL
  private let fileManager: FileManager
  private let dateProvider: @Sendable () -> Date
  private let lock = NSLock()

  init(
    fileURL: URL,
    fileManager: FileManager = .default,
    dateProvider: @escaping @Sendable () -> Date = Date.init
  ) {
    self.fileURL = fileURL
    self.fileManager = fileManager
    self.dateProvider = dateProvider
  }

  func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: dateProvider())
    let line = "[\(timestamp)] \(message)\n"

    lock.lock()
    defer {
      lock.unlock()
    }

    do {
      try fileManager.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )

      if shouldResetLogFile() {
        try Data().write(to: fileURL, options: .atomic)
      } else if !fileManager.fileExists(atPath: fileURL.fileSystemPath) {
        try Data().write(to: fileURL, options: .atomic)
      }

      let handle = try FileHandle(forWritingTo: fileURL)
      defer {
        try? handle.close()
      }

      try handle.seekToEnd()
      try handle.write(contentsOf: Data(line.utf8))
    } catch {
      Self.fallbackLogger.error("Failed to write diagnostic log: \(String(describing: error), privacy: .public)")
      fputs("Failed to write diagnostic log: \(error)\n", stderr)
    }
  }

  private func shouldResetLogFile() -> Bool {
    guard
      let sizeValue = try? fileManager.attributesOfItem(atPath: fileURL.fileSystemPath)[.size] as? NSNumber
    else {
      return false
    }

    return sizeValue.intValue >= Self.maximumFileSizeBytes
  }
}

private extension URL {
  var fileSystemPath: String {
    path(percentEncoded: false)
  }
}

enum DiagnosticLoggerFactory {
  static func makeDefault(
    fileManager: FileManager = .default,
    applicationSupportURL: URL? = nil
  ) -> any DiagnosticLogging {
    FileDiagnosticLogger(
      fileURL: defaultLogFileURL(
        fileManager: fileManager,
        applicationSupportURL: applicationSupportURL
      ),
      fileManager: fileManager
    )
  }

  static func defaultLogFileURL(
    fileManager: FileManager = .default,
    applicationSupportURL: URL? = nil
  ) -> URL {
    let baseURL =
      applicationSupportURL
      ?? (try? fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      ))
      ?? fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)

    return baseURL
      .appendingPathComponent("ShortClip", isDirectory: true)
      .appendingPathComponent("Logs", isDirectory: true)
      .appendingPathComponent("shortclip.log")
  }
}
