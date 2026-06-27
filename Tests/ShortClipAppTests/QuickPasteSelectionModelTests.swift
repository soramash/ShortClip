import Testing
@testable import ShortClipApp

struct QuickPasteSelectionModelTests {
  @Test
  func selectsFirstItemByDefault() {
    let model = QuickPasteSelectionModel(
      itemIDs: ["history-1", "history-2", "snippet-1"]
    )

    #expect(model.selectedItemID == "history-1")
  }

  @Test
  func movesSelectionUpAndDownWithWraparound() {
    let initialModel = QuickPasteSelectionModel(
      itemIDs: ["history-1", "history-2", "snippet-1"]
    )
    let wrappedToBottom = initialModel.moveUp()
    let movedDown = wrappedToBottom.moveDown()
    let wrappedToTop = wrappedToBottom.moveDown()

    #expect(wrappedToBottom.selectedItemID == "snippet-1")
    #expect(movedDown.selectedItemID == "history-1")
    #expect(wrappedToTop.selectedItemID == "history-1")
  }

  @Test
  func keepsSelectionNilWhenNoItemsExist() {
    let model = QuickPasteSelectionModel(itemIDs: [])

    #expect(model.selectedItemID == nil)
    #expect(model.moveDown().selectedItemID == nil)
    #expect(model.moveUp().selectedItemID == nil)
  }

  @Test
  func resetsSelectionWhenItemIDsChange() {
    let model = QuickPasteSelectionModel(itemIDs: ["history-1", "history-2"])
      .moveDown()
      .updatingItemIDs(["snippet-9", "history-9"])

    #expect(model.selectedItemID == "snippet-9")
  }

  @Test
  func showsDetailForSelectedItemWhenRequested() {
    let model = QuickPasteSelectionModel(itemIDs: ["history-1", "snippet-1"])
      .showDetail()

    #expect(model.selectedItemID == "history-1")
    #expect(model.isShowingDetail == true)
  }

  @Test
  func hidesDetailWhenRequested() {
    let model = QuickPasteSelectionModel(itemIDs: ["history-1", "snippet-1"])
      .showDetail()
      .hideDetail()

    #expect(model.isShowingDetail == false)
    #expect(model.selectedItemID == "history-1")
  }

  @Test
  func keepsDetailVisibleWhileSelectionWraps() {
    let model = QuickPasteSelectionModel(itemIDs: ["history-1", "snippet-1"])
      .showDetail()
      .moveUp()

    #expect(model.isShowingDetail == true)
    #expect(model.selectedItemID == "snippet-1")
  }

  @Test
  func doesNotShowDetailWhenNoItemsExist() {
    let model = QuickPasteSelectionModel(itemIDs: [])
      .showDetail()

    #expect(model.isShowingDetail == false)
    #expect(model.selectedItemID == nil)
  }

  @Test
  func selectsItemByOneBasedRowNumber() {
    let initialModel = QuickPasteSelectionModel(
      itemIDs: ["history-1", "history-2", "snippet-1"]
    )
    let selectedSecond = initialModel.selectRowNumber(2)
    let selectedThird = selectedSecond.selectRowNumber(3)

    #expect(selectedSecond.selectedItemID == "history-2")
    #expect(selectedThird.selectedItemID == "snippet-1")
  }

  @Test
  func ignoresInvalidRowNumbers() {
    let model = QuickPasteSelectionModel(
      itemIDs: ["history-1", "history-2", "snippet-1"]
    )
    let selectedInvalidLow = model.selectRowNumber(0)
    let selectedInvalidHigh = model.selectRowNumber(4)

    #expect(selectedInvalidLow.selectedItemID == "history-1")
    #expect(selectedInvalidHigh.selectedItemID == "history-1")
  }
}
