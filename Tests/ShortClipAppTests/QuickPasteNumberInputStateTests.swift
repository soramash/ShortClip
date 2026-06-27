import Foundation
import Testing
@testable import ShortClipApp

struct QuickPasteNumberInputStateTests {
  @Test
  func selectsSingleDigitRowNumber() {
    let state = QuickPasteNumberInputState(inputTimeout: 0.6)

    let first = state.registeringDigit(
      3,
      now: Date(timeIntervalSince1970: 10),
      maxRowNumber: 20
    )

    #expect(first.selectedRowNumber == 3)
  }

  @Test
  func combinesMultipleDigitsWithinTimeout() {
    let state = QuickPasteNumberInputState(inputTimeout: 0.6)

    let first = state.registeringDigit(
      1,
      now: Date(timeIntervalSince1970: 10),
      maxRowNumber: 20
    )
    let second = first.state.registeringDigit(
      2,
      now: Date(timeIntervalSince1970: 10.4),
      maxRowNumber: 20
    )

    #expect(first.selectedRowNumber == 1)
    #expect(second.selectedRowNumber == 12)
  }

  @Test
  func startsNewSelectionAfterTimeout() {
    let state = QuickPasteNumberInputState(inputTimeout: 0.6)

    let first = state.registeringDigit(
      1,
      now: Date(timeIntervalSince1970: 10),
      maxRowNumber: 20
    )
    let second = first.state.registeringDigit(
      2,
      now: Date(timeIntervalSince1970: 10.8),
      maxRowNumber: 20
    )

    #expect(second.selectedRowNumber == 2)
  }

  @Test
  func ignoresLeadingZero() {
    let state = QuickPasteNumberInputState(inputTimeout: 0.6)

    let first = state.registeringDigit(
      0,
      now: Date(timeIntervalSince1970: 10),
      maxRowNumber: 20
    )
    let second = first.state.registeringDigit(
      7,
      now: Date(timeIntervalSince1970: 10.1),
      maxRowNumber: 20
    )

    #expect(first.selectedRowNumber == nil)
    #expect(second.selectedRowNumber == 7)
  }

  @Test
  func fallsBackToNewestValidSingleDigitWhenCombinedNumberIsOutOfRange() {
    let state = QuickPasteNumberInputState(inputTimeout: 0.6)

    let first = state.registeringDigit(
      2,
      now: Date(timeIntervalSince1970: 10),
      maxRowNumber: 20
    )
    let second = first.state.registeringDigit(
      5,
      now: Date(timeIntervalSince1970: 10.2),
      maxRowNumber: 20
    )

    #expect(first.selectedRowNumber == 2)
    #expect(second.selectedRowNumber == 5)
  }
}
