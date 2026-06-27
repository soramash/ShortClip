import Foundation
import Testing
@testable import ShortClipApp

@MainActor
struct LaunchAtLoginManagerTests {
  @Test
  func loadsInitialLaunchAtLoginStatus() {
    let service = TestLaunchAtLoginService(status: .enabled)

    let manager = LaunchAtLoginManager(service: service)

    #expect(manager.status == .enabled)
    #expect(manager.isEnabled)
  }

  @Test
  func enablingLaunchAtLoginRegistersMainApp() {
    let service = TestLaunchAtLoginService(
      status: .disabled,
      registerResultStatus: .enabled
    )
    let manager = LaunchAtLoginManager(service: service)

    manager.setLaunchAtLoginEnabled(true)

    #expect(service.registerCallCount == 1)
    #expect(service.unregisterCallCount == 0)
    #expect(manager.status == .enabled)
    #expect(manager.isEnabled)
  }

  @Test
  func enablingLaunchAtLoginCanRequireApproval() {
    let service = TestLaunchAtLoginService(
      status: .disabled,
      registerResultStatus: .requiresApproval
    )
    let manager = LaunchAtLoginManager(service: service)

    manager.setLaunchAtLoginEnabled(true)

    #expect(manager.status == .requiresApproval)
    #expect(manager.isEnabled)
  }

  @Test
  func disablingLaunchAtLoginUnregistersMainApp() {
    let service = TestLaunchAtLoginService(
      status: .enabled,
      unregisterResultStatus: .disabled
    )
    let manager = LaunchAtLoginManager(service: service)

    manager.setLaunchAtLoginEnabled(false)

    #expect(service.registerCallCount == 0)
    #expect(service.unregisterCallCount == 1)
    #expect(manager.status == .disabled)
    #expect(!manager.isEnabled)
  }

  @Test
  func openingLoginItemsDelegatesToService() {
    let service = TestLaunchAtLoginService(status: .disabled)
    let manager = LaunchAtLoginManager(service: service)

    manager.openSystemSettingsLoginItems()

    #expect(service.openSystemSettingsCallCount == 1)
  }
}

@MainActor
private final class TestLaunchAtLoginService: LaunchAtLoginServicing {
  var status: LaunchAtLoginStatus
  private let registerResultStatus: LaunchAtLoginStatus
  private let unregisterResultStatus: LaunchAtLoginStatus
  private(set) var registerCallCount = 0
  private(set) var unregisterCallCount = 0
  private(set) var openSystemSettingsCallCount = 0

  init(
    status: LaunchAtLoginStatus,
    registerResultStatus: LaunchAtLoginStatus? = nil,
    unregisterResultStatus: LaunchAtLoginStatus? = nil
  ) {
    self.status = status
    self.registerResultStatus = registerResultStatus ?? status
    self.unregisterResultStatus = unregisterResultStatus ?? status
  }

  func register() throws {
    registerCallCount += 1
    status = registerResultStatus
  }

  func unregister() throws {
    unregisterCallCount += 1
    status = unregisterResultStatus
  }

  func openSystemSettingsLoginItems() {
    openSystemSettingsCallCount += 1
  }
}
