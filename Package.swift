// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "markplay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "markplay", targets: ["markplay"])
    ],
    targets: [
        .executableTarget(
            name: "markplay",
            path: "Sources/markplay",
            exclude: ["Resources"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "markplayTests",
            dependencies: ["markplay"],
            path: "Tests/markplayTests"
        )
    ]
)
