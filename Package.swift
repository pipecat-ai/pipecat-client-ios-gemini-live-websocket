// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RTVIClientIOSWSPrototype",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "RTVIClientIOSWSPrototype",
            targets: ["RTVIClientIOSWSPrototype"]),
    ],
    dependencies: [
        // Local dependency
        .package(path: "../rtvi-client-ios"),
        // .package(url: "https://github.com/rtvi-ai/rtvi-client-ios.git", from: "0.2.0"),
        // TODO: we can remove this once we're done with the prototyping. Useful to have it here to refer to types
        .package(url: "https://github.com/daily-co/daily-client-ios.git", from: "0.23.0")
    ],
    targets: [
        .target(
            name: "RTVIClientIOSWSPrototype",
            dependencies: [
                .product(name: "RTVIClientIOS", package: "rtvi-client-ios"),
                // TODO: we can remove this once we're done with the prototyping. Useful to have it here to refer to types
                .product(name: "Daily", package: "daily-client-ios")
            ]),
        .testTarget(
            name: "RTVIClientIOSWSPrototypeTests",
            dependencies: ["RTVIClientIOSWSPrototype"]),
    ]
)
