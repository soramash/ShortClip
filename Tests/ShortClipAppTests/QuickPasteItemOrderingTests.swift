import Testing
@testable import ShortClipApp

struct QuickPasteItemOrderingTests {
  @Test
  func quickPasteOrderingPlacesHistoryBeforeSnippets() {
    let snippets = ["snippet-1", "snippet-2"]
    let history = ["history-1", "history-2"]

    let ordered = QuickPasteItemOrdering.forQuickPaste(
      snippetItems: snippets,
      historyItems: history
    )

    #expect(ordered == ["history-1", "history-2", "snippet-1", "snippet-2"])
  }

  @Test
  func libraryOrderingKeepsSnippetsBeforeHistory() {
    let snippets = ["snippet-1", "snippet-2"]
    let history = ["history-1", "history-2"]

    let ordered = QuickPasteItemOrdering.forLibrary(
      snippetItems: snippets,
      historyItems: history
    )

    #expect(ordered == ["snippet-1", "snippet-2", "history-1", "history-2"])
  }
}
