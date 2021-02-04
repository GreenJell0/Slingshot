// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Slingshot",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "Slingshot",
            targets: ["Slingshot"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Slingshot",
            dependencies: [],
            resources: [
                .process("Resources/Slingshot/Images.xcasset")
            ]),
        .testTarget(
            name: "SlingshotTests",
            dependencies: ["Slingshot"]),
    ]
)
