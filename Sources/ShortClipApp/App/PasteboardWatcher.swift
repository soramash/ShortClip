import AppKit
import Foundation

@MainActor
protocol PasteboardWatching: AnyObject {
  func start()
  func stop()
  func write(text: String)
}

@MainActor
final class PasteboardWatcher: PasteboardWatching {
  private let pasteboard: NSPasteboard
  private let pollInterval: TimeInterval
  private let onCopiedText: (String) -> Void
  private let onTick: () -> Void
  private var timer: Timer?
  private var lastChangeCount: Int

  init(
    pasteboard: NSPasteboard = .general,
    pollInterval: TimeInterval = 0.75,
    onCopiedText: @escaping (String) -> Void,
    onTick: @escaping () -> Void
  ) {
    self.pasteboard = pasteboard
    self.pollInterval = pollInterval
    self.onCopiedText = onCopiedText
    self.onTick = onTick
    self.lastChangeCount = pasteboard.changeCount
  }

  func start() {
    guard timer == nil else {
      return
    }

    timer = Timer.scheduledTimer(
      withTimeInterval: pollInterval,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.poll()
      }
    }

    if let timer {
      RunLoop.main.add(timer, forMode: .common)
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  func write(text: String) {
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    lastChangeCount = pasteboard.changeCount
  }

  private func poll() {
    onTick()

    guard pasteboard.changeCount != lastChangeCount else {
      return
    }

    lastChangeCount = pasteboard.changeCount

    guard let copiedText = pasteboard.string(forType: .string) else {
      return
    }

    onCopiedText(copiedText)
  }
}
