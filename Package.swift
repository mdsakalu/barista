// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Barista",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Barista", targets: ["BaristaApp"])
    ],
    targets: [
        .executableTarget(
            name: "BaristaApp",
            path: "Sources/BaristaApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BaristaAppTests",
            dependencies: ["BaristaApp"]
        )
    ]
)
