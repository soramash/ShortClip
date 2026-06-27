enum QuickPasteItemOrdering {
  static func forQuickPaste<Item>(
    snippetItems: [Item],
    historyItems: [Item]
  ) -> [Item] {
    historyItems + snippetItems
  }

  static func forLibrary<Item>(
    snippetItems: [Item],
    historyItems: [Item]
  ) -> [Item] {
    snippetItems + historyItems
  }
}
