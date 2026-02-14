// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MessageExporterApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MessageExporterApp", targets: ["MessageExporterApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.3")
    ],
    targets: [
        .executableTarget(
            name: "MessageExporterApp",
            dependencies: ["CryptoSwift"],
            path: "Sources",
            resources: [.process("../Resources")],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-warn-concurrency"])
            ]
        ),
        .testTarget(
            name: "MessageExporterTests",
            dependencies: ["MessageExporterApp"],
            path: "Tests/MessageExporterTests"
        )
    ]
)
