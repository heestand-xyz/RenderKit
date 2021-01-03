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
    dependencies: [],
    targets: [
        .target(name: "RenderKit", dependencies: [], path: "Source"),
        .testTarget(name: "RenderKitTests", dependencies: ["RenderKit"]),
    ]
)
