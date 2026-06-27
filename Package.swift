// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ShortClip",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "ShortClipCore",
      targets: ["ShortClipCore"]
    ),
    .executable(
      name: "ShortClipApp",
      targets: ["ShortClipApp"]
    )
  ],
  targets: [
    .target(
      name: "ShortClipCore",
      path: "Sources/ShortClipCore"
    ),
    .executableTarget(
      name: "ShortClipApp",
      dependencies: ["ShortClipCore"],
      path: "Sources/ShortClipApp"
    ),
    .testTarget(
      name: "ShortClipCoreTests",
      dependencies: ["ShortClipCore"],
      path: "Tests/ShortClipCoreTests"
    ),
    .testTarget(
      name: "ShortClipAppTests",
      dependencies: ["ShortClipApp", "ShortClipCore"],
      path: "Tests/ShortClipAppTests"
    )
  ]
)
