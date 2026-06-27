import Foundation
import Testing
@testable import ShortClipApp

struct AppVersionTests {
  @Test
  func formatsDisplayTextFromBundleInfo() {
    let version = AppVersion(
      infoDictionary: [
        "CFBundleShortVersionString": "1.2.3",
        "CFBundleVersion": "45"
      ]
    )

    #expect(version.displayText == "v1.2.3 (45)")
  }

  @Test
  func fallsBackWhenBundleInfoIsMissing() {
    let version = AppVersion(infoDictionary: [:])

    #expect(version.displayText == "vdev")
  }
}
