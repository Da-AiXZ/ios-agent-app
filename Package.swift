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
    dependencies: [
        .package(
            url: "https://github.com/ChimeHQ/Neon.git",
            .upToNextMinor(from: "0.5.0")
        ),
        .package(
            url: "https://github.com/apple/swift-markdown.git",
            .upToNextMinor(from: "0.3.0")
        ),
    ],
    targets: [
        .target(
            name: "ios-agent-app",
            dependencies: [
                .product(name: "Neon", package: "Neon"),
                .product(name: "Markdown", package: "swift-markdown"),
            ],
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
