// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "RenderKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13)
    ],
    products: [
        .library(name: "RenderKit", targets: ["RenderKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/PixelColor.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "RenderKit", dependencies: ["PixelColor"], path: "Source"),
        .testTarget(name: "RenderKitTests", dependencies: ["RenderKit"]),
    ]
)
