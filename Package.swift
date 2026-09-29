// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WindowLayout",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WindowLayoutCore"),
        .executableTarget(name: "WindowLayout", dependencies: ["WindowLayoutCore"]),
        .testTarget(name: "WindowLayoutTests", dependencies: ["WindowLayoutCore"]),
    ]
)
