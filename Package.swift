// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MiniVocab",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MiniVocab", targets: ["MiniVocab"])
    ],
    targets: [
        .executableTarget(
            name: "MiniVocab",
            dependencies: [],
            path: "MiniVocab",
            exclude: [],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("SwiftData")
            ]
        ),
        .testTarget(
            name: "MiniVocabTests",
            dependencies: ["MiniVocab"],
            path: "MiniVocabTests"
        ),
    ]
)
