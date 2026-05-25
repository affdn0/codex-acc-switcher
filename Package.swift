// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "codex-acc-switcher",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexAccountSwitcherCore", targets: ["CodexAccountSwitcherCore"]),
        .executable(name: "CodexAccountSwitcher", targets: ["CodexAccountSwitcher"]),
    ],
    targets: [
        .target(name: "CodexAccountSwitcherCore"),
        .executableTarget(
            name: "CodexAccountSwitcher",
            dependencies: ["CodexAccountSwitcherCore"],
            linkerSettings: [.linkedFramework("SwiftUI"), .linkedFramework("AppKit")]
        ),
        .testTarget(name: "CodexAccountSwitcherTests", dependencies: ["CodexAccountSwitcherCore"]),
    ]
)
