// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HamStationBridge",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../../Packages/HamStationKit"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "HamStationBridge",
            dependencies: [
                .product(name: "HamStationKit", package: "HamStationKit"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird"),
            ],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
