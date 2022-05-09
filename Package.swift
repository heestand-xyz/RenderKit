// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "RenderKit",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "RenderKit", targets: ["RenderKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/PixelColor", from: "1.3.2"),
        .package(url: "https://github.com/heestand-xyz/Resolution", from: "1.0.4"),
        .package(url: "https://github.com/heestand-xyz/TextureMap", from: "0.5.2"),
    ],
    targets: [
        .target(name: "RenderKit", dependencies: ["PixelColor", "Resolution", "TextureMap"], path: "Source"),
        .testTarget(name: "RenderKitTests", dependencies: ["RenderKit"]),
    ]
)
