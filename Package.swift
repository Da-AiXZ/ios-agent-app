// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ios-agent-app",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "ios-agent-app",
            targets: ["ios-agent-app"]
        ),
    ],
    targets: [
        .target(
            name: "ios-agent-app",
            path: "Sources",
            exclude: []
        ),
        .testTarget(
            name: "ios-agent-appTests",
            dependencies: ["ios-agent-app"],
            path: "Tests"
        ),
    ]
)
