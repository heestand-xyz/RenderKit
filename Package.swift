// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "RenderKit",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_13),
        .tvOS(.v11),
    ],
    products: [
        .library(name: "RenderKit", targets: ["RenderKit"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "RenderKit", dependencies: [], path: "Source"),
        .testTarget(name: "RenderKitTests", dependencies: ["RenderKit"]),
    ]
)
