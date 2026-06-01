// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iTickerCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "iTickerCore",
            targets: ["iTickerCore"]
        ),
    ],
    targets: [
        .target(
            name: "iTickerCore",
            dependencies: [],
            path: "Sources/iTickerCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "iTickerCoreTests",
            dependencies: ["iTickerCore"],
            path: "Tests/iTickerCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
