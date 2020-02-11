// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "RenderKit",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_12),
        .tvOS(.v11)
    ],
    products: [
        .library(name: "RenderKit", targets: ["RenderKit"]),
    ],
    dependencies: [
//        .package(path: "../../../Frameworks/Production/LiveValues"),
        .package(url: "https://github.com/hexagons/LiveValues.git", from: "1.1.7")
    ],
    targets: [
        .target(name: "RenderKit", dependencies: ["LiveValues"], path: "Source")
    ]
)
