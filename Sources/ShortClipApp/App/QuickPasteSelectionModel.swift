import Foundation

struct QuickPasteSelectionModel: Equatable {
  let itemIDs: [String]
  let selectedIndex: Int?
  let isShowingDetail: Bool

  init(
    itemIDs: [String],
    selectedIndex: Int? = nil,
    isShowingDetail: Bool = false
  ) {
    self.itemIDs = itemIDs
    self.selectedIndex = Self.normalizedSelectionIndex(
      itemIDs: itemIDs,
      selectedIndex: selectedIndex
    )
    self.isShowingDetail = self.selectedIndex == nil ? false : isShowingDetail
  }

  var selectedItemID: String? {
    guard let selectedIndex else {
      return nil
    }

    return itemIDs[selectedIndex]
  }

  func moveUp() -> QuickPasteSelectionModel {
    guard let selectedIndex else {
      return self
    }

    return QuickPasteSelectionModel(
      itemIDs: itemIDs,
      selectedIndex: selectedIndex == 0 ? itemIDs.count - 1 : selectedIndex - 1,
      isShowingDetail: isShowingDetail
    )
  }

  func moveDown() -> QuickPasteSelectionModel {
    guard let selectedIndex else {
      return self
    }

    return QuickPasteSelectionModel(
      itemIDs: itemIDs,
      selectedIndex: selectedIndex == itemIDs.count - 1 ? 0 : selectedIndex + 1,
      isShowingDetail: isShowingDetail
    )
  }

  func selectRowNumber(_ rowNumber: Int) -> QuickPasteSelectionModel {
    guard (1...itemIDs.count).contains(rowNumber) else {
      return self
    }

    return QuickPasteSelectionModel(
      itemIDs: itemIDs,
      selectedIndex: rowNumber - 1,
      isShowingDetail: isShowingDetail
    )
  }

  func updatingItemIDs(_ itemIDs: [String]) -> QuickPasteSelectionModel {
    QuickPasteSelectionModel(
      itemIDs: itemIDs,
      isShowingDetail: isShowingDetail
    )
  }

  func showDetail() -> QuickPasteSelectionModel {
    QuickPasteSelectionModel(
      itemIDs: itemIDs,
      selectedIndex: selectedIndex,
      isShowingDetail: true
    )
  }

  func hideDetail() -> QuickPasteSelectionModel {
    QuickPasteSelectionModel(
      itemIDs: itemIDs,
      selectedIndex: selectedIndex,
      isShowingDetail: false
    )
  }

  private static func normalizedSelectionIndex(
    itemIDs: [String],
    selectedIndex: Int?
  ) -> Int? {
    guard !itemIDs.isEmpty else {
      return nil
    }

    guard let selectedIndex else {
      return 0
    }

    return min(max(0, selectedIndex), itemIDs.count - 1)
  }
}
