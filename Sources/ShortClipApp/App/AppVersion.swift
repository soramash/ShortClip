import Foundation

struct AppVersion: Equatable {
  let marketingVersion: String
  let buildNumber: String?

  init(
    marketingVersion: String,
    buildNumber: String? = nil
  ) {
    self.marketingVersion = marketingVersion
    self.buildNumber = Self.normalizedComponent(buildNumber)
  }

  init(infoDictionary: [String: Any]) {
    let marketingVersion = Self.normalizedComponent(
      infoDictionary["CFBundleShortVersionString"] as? String
    ) ?? "dev"
    let buildNumber = Self.normalizedComponent(
      infoDictionary["CFBundleVersion"] as? String
    )

    self.init(
      marketingVersion: marketingVersion,
      buildNumber: buildNumber
    )
  }

  static func current(bundle: Bundle = .main) -> AppVersion {
    AppVersion(infoDictionary: bundle.infoDictionary ?? [:])
  }

  var displayText: String {
    guard let buildNumber, buildNumber != marketingVersion else {
      return "v\(marketingVersion)"
    }

    return "v\(marketingVersion) (\(buildNumber))"
  }

  private static func normalizedComponent(_ value: String?) -> String? {
    let normalizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return normalizedValue.isEmpty ? nil : normalizedValue
  }
}
