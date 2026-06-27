import Foundation

struct QuickPasteNumberInputState: Equatable {
  let bufferedDigits: String
  let lastInputAt: Date?
  let inputTimeout: TimeInterval

  init(
    bufferedDigits: String = "",
    lastInputAt: Date? = nil,
    inputTimeout: TimeInterval = 0.6
  ) {
    self.bufferedDigits = bufferedDigits
    self.lastInputAt = lastInputAt
    self.inputTimeout = inputTimeout
  }

  func registeringDigit(
    _ digit: Int,
    now: Date,
    maxRowNumber: Int
  ) -> QuickPasteNumberInputResult {
    guard (0...9).contains(digit), maxRowNumber > 0 else {
      return QuickPasteNumberInputResult(
        state: reset(),
        selectedRowNumber: nil
      )
    }

    let activeDigits = currentDigits(at: now)
    let combinedDigits = activeDigits + "\(digit)"

    if let combinedRowNumber = Self.validRowNumber(
      for: combinedDigits,
      maxRowNumber: maxRowNumber
    ) {
      return QuickPasteNumberInputResult(
        state: QuickPasteNumberInputState(
          bufferedDigits: combinedDigits,
          lastInputAt: now,
          inputTimeout: inputTimeout
        ),
        selectedRowNumber: combinedRowNumber
      )
    }

    let singleDigits = "\(digit)"

    if let singleRowNumber = Self.validRowNumber(
      for: singleDigits,
      maxRowNumber: maxRowNumber
    ) {
      return QuickPasteNumberInputResult(
        state: QuickPasteNumberInputState(
          bufferedDigits: singleDigits,
          lastInputAt: now,
          inputTimeout: inputTimeout
        ),
        selectedRowNumber: singleRowNumber
      )
    }

    return QuickPasteNumberInputResult(
      state: reset(),
      selectedRowNumber: nil
    )
  }

  func reset() -> QuickPasteNumberInputState {
    QuickPasteNumberInputState(inputTimeout: inputTimeout)
  }

  private func currentDigits(at now: Date) -> String {
    guard let lastInputAt else {
      return ""
    }

    guard now.timeIntervalSince(lastInputAt) <= inputTimeout else {
      return ""
    }

    return bufferedDigits
  }

  private static func validRowNumber(
    for digits: String,
    maxRowNumber: Int
  ) -> Int? {
    guard let rowNumber = Int(digits) else {
      return nil
    }

    guard (1...maxRowNumber).contains(rowNumber) else {
      return nil
    }

    return rowNumber
  }
}

struct QuickPasteNumberInputResult: Equatable {
  let state: QuickPasteNumberInputState
  let selectedRowNumber: Int?
}
