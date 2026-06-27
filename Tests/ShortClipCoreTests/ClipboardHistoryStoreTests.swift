import Foundation
import Testing
@testable import ShortClipCore

struct ClipboardHistoryStoreTests {
  @Test
  func insertsNewClipboardEntryAtFront() {
    let now = Date(timeIntervalSince1970: 1_000)
    var store = ClipboardHistoryStore(now: { now })

    store.recordCopy(text: "alpha")

    #expect(store.history.map(\.text) == ["alpha"])
  }

  @Test
  func ignoresBlankClipboardValues() {
    let now = Date(timeIntervalSince1970: 1_000)
    var store = ClipboardHistoryStore(now: { now })

    store.recordCopy(text: "   \n")

    #expect(store.history.isEmpty)
  }

  @Test
  func keepsOnlyLatestTwentyEntries() {
    let now = Date(timeIntervalSince1970: 1_000)
    var store = ClipboardHistoryStore(now: { now })

    (0..<25)
      .map { "item-\($0)" }
      .forEach { store.recordCopy(text: $0) }

    #expect(store.history.count == 20)
    #expect(store.history.first?.text == "item-24")
    #expect(store.history.last?.text == "item-5")
  }

  @Test
  func prunesEntriesOlderThanOneHour() {
    let base = Date(timeIntervalSince1970: 10_000)
    let clock = TestClock(now: base)
    var store = ClipboardHistoryStore(now: { clock.now })

    store.recordCopy(text: "fresh")
    clock.advance(by: 60 * 60 + 1)
    store.recordCopy(text: "new")

    #expect(store.history.map(\.text) == ["new"])
  }

  @Test
  func pruneExpiredRemovesStaleEntriesWithoutNewCopy() {
    let base = Date(timeIntervalSince1970: 15_000)
    let clock = TestClock(now: base)
    var store = ClipboardHistoryStore(now: { clock.now })

    store.recordCopy(text: "fresh")
    clock.advance(by: 60 * 60 + 1)
    store.pruneExpired()

    #expect(store.history.isEmpty)
  }

  @Test
  func recalledEntryMovesToFrontAndRefreshesTimestamp() throws {
    let base = Date(timeIntervalSince1970: 20_000)
    let clock = TestClock(now: base)
    var store = ClipboardHistoryStore(now: { clock.now })

    store.recordCopy(text: "first")
    clock.advance(by: 60)
    store.recordCopy(text: "second")

    let firstId = try #require(store.history.last?.id)
    clock.advance(by: 60)
    let recalled = store.recall(id: firstId)

    #expect(recalled?.text == "first")
    #expect(store.history.map(\.text) == ["first", "second"])
    #expect(store.history.first?.copiedAt == clock.now)
  }

  @Test
  func clearRemovesAllHistoryEntries() {
    let now = Date(timeIntervalSince1970: 25_000)
    var store = ClipboardHistoryStore(now: { now })

    store.recordCopy(text: "alpha")
    store.recordCopy(text: "beta")
    store.clear()

    #expect(store.history.isEmpty)
  }

  @Test
  func deleteRemovesOnlyRequestedHistoryEntry() throws {
    let now = Date(timeIntervalSince1970: 26_000)
    var store = ClipboardHistoryStore(now: { now })

    store.recordCopy(text: "alpha")
    store.recordCopy(text: "beta")
    let alphaID = try #require(store.history.last?.id)

    store.delete(id: alphaID)

    #expect(store.history.map(\.text) == ["beta"])
  }
}

private final class TestClock: @unchecked Sendable {
  private(set) var now: Date

  init(now: Date) {
    self.now = now
  }

  func advance(by seconds: TimeInterval) {
    now = now.addingTimeInterval(seconds)
  }
}
