import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
  case disabled
  case enabled
  case requiresApproval
  case unavailable

  var isEnabled: Bool {
    switch self {
    case .enabled, .requiresApproval:
      true
    case .disabled, .unavailable:
      false
    }
  }

  var logValue: String {
    switch self {
    case .disabled:
      "disabled"
    case .enabled:
      "enabled"
    case .requiresApproval:
      "requires_approval"
    case .unavailable:
      "unavailable"
    }
  }
}

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
  var status: LaunchAtLoginStatus { get }
  func register() throws
  func unregister() throws
  func openSystemSettingsLoginItems()
}

final class MainAppLaunchAtLoginService: LaunchAtLoginServicing {
  private let service: SMAppService

  init(service: SMAppService = .mainApp) {
    self.service = service
  }

  var status: LaunchAtLoginStatus {
    switch service.status {
    case .notRegistered:
      .disabled
    case .enabled:
      .enabled
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .unavailable
    @unknown default:
      .unavailable
    }
  }

  func register() throws {
    try service.register()
  }

  func unregister() throws {
    try service.unregister()
  }

  func openSystemSettingsLoginItems() {
    SMAppService.openSystemSettingsLoginItems()
  }
}

@MainActor
final class LaunchAtLoginManager: ObservableObject {
  @Published private(set) var status: LaunchAtLoginStatus

  private let service: LaunchAtLoginServicing
  private let logger: @Sendable (String) -> Void

  init(
    service: LaunchAtLoginServicing = MainAppLaunchAtLoginService(),
    logger: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.service = service
    self.logger = logger
    self.status = service.status
    logger("launch_at_login_init status=\(status.logValue)")
  }

  var isEnabled: Bool {
    status.isEnabled
  }

  var needsApproval: Bool {
    status == .requiresApproval
  }

  func refreshStatus() {
    status = service.status
    logger("launch_at_login_refresh status=\(status.logValue)")
  }

  func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
    do {
      if isEnabled {
        try service.register()
      } else {
        try service.unregister()
      }

      refreshStatus()
      logger("launch_at_login_update desired=\(isEnabled) status=\(status.logValue)")
    } catch {
      refreshStatus()
      logger(
        "launch_at_login_update_failed desired=\(isEnabled) status=\(status.logValue) error=\(String(describing: error))"
      )
    }
  }

  func openSystemSettingsLoginItems() {
    logger("launch_at_login_open_system_settings")
    service.openSystemSettingsLoginItems()
  }
}
