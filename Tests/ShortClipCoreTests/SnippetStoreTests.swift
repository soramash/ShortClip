import Foundation
import Testing
@testable import ShortClipCore

struct SnippetStoreTests {
  @Test
  func addsSnippetWithTrimmedTitle() {
    let now = Date(timeIntervalSince1970: 30_000)
    var store = SnippetStore(now: { now })

    let snippet = store.addSnippet(
      title: "  Greeting  ",
      text: "Hello from ShortClip"
    )

    #expect(snippet?.title == "Greeting")
    #expect(store.snippets.map(\.title) == ["Greeting"])
  }

  @Test
  func updatesExistingSnippetTextAndMovesItToFront() throws {
    let base = Date(timeIntervalSince1970: 40_000)
    let clock = SnippetClock(now: base)
    var store = SnippetStore(now: { clock.now })

    let initialSnippet = store.addSnippet(title: "First", text: "one")
    let first = try #require(initialSnippet)
    clock.advance(by: 60)
    _ = store.addSnippet(title: "Second", text: "two")
    clock.advance(by: 60)

    let updated = store.updateSnippet(
      id: first.id,
      title: "First",
      text: "updated"
    )

    #expect(updated?.text == "updated")
    #expect(store.snippets.map(\.title) == ["First", "Second"])
    #expect(store.snippets.first?.updatedAt == clock.now)
  }

  @Test
  func deletesSnippet() throws {
    let now = Date(timeIntervalSince1970: 50_000)
    var store = SnippetStore(now: { now })

    let storedSnippet = store.addSnippet(title: "Disposable", text: "tmp")
    let snippet = try #require(storedSnippet)
    store.deleteSnippet(id: snippet.id)

    #expect(store.snippets.isEmpty)
  }

  @Test
  func recalledSnippetMovesToFront() throws {
    let base = Date(timeIntervalSince1970: 60_000)
    let clock = SnippetClock(now: base)
    var store = SnippetStore(now: { clock.now })

    let initialSnippet = store.addSnippet(title: "First", text: "one")
    let first = try #require(initialSnippet)
    clock.advance(by: 60)
    _ = store.addSnippet(title: "Second", text: "two")
    clock.advance(by: 60)

    let recalled = store.recall(id: first.id)

    #expect(recalled?.title == "First")
    #expect(store.snippets.map(\.title) == ["First", "Second"])
    #expect(store.snippets.first?.updatedAt == clock.now)
  }
}

private final class SnippetClock: @unchecked Sendable {
  private(set) var now: Date

  init(now: Date) {
    self.now = now
  }

  func advance(by seconds: TimeInterval) {
    now = now.addingTimeInterval(seconds)
  }
}
