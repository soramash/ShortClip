import Testing
@testable import ShortClipApp

@MainActor
struct SettingsWindowOpenerTests {
  @Test
  func openSettingsActivatesAppAndSendsSettingsAction() {
    let recorder = InvocationRecorder()
    let opener = SettingsWindowOpener(
      activateApp: {
        recorder.append("activate")
      },
      sendSettingsAction: {
        recorder.append("sendAction")
        return true
      },
      logger: { message in
        recorder.append(message)
      }
    )

    opener.openSettings()

    #expect(
      recorder.values == [
        "settings_fallback_requested",
        "activate",
        "sendAction",
        "settings_fallback_result sent=true"
      ]
    )
  }

  @Test
  func openSettingsStillSendsActionWhenFirstAttemptFails() {
    var didActivate = false
    var sendAttempts = 0
    let recorder = InvocationRecorder()
    let opener = SettingsWindowOpener(
      activateApp: {
        didActivate = true
      },
      sendSettingsAction: {
        sendAttempts += 1
        return false
      },
      logger: { message in
        recorder.append(message)
      }
    )

    opener.openSettings()

    #expect(didActivate)
    #expect(sendAttempts == 1)
    #expect(recorder.values.last == "settings_fallback_result sent=false")
  }
}

private final class InvocationRecorder: @unchecked Sendable {
  private(set) var values: [String] = []

  func append(_ value: String) {
    values = values + [value]
  }
}
