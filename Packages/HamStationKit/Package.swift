// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HamStationKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "HamStationKit", targets: ["HamStationKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "HamStationKit",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources",
            exclude: ["UI/WaterfallView/WaterfallShaders.metal"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "HamStationKitTests",
            dependencies: ["HamStationKit"],
            path: "Tests",
            resources: [
                .copy("ADIFTests/Fixtures")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
