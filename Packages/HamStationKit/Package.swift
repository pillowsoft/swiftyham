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
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", branch: "main")
    ],
    targets: [
        .target(
            name: "HamStationKit",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm")
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
