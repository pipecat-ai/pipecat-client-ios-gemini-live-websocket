// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PipecatClientIOSGeminiLiveWebSocket",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PipecatClientIOSGeminiLiveWebSocket",
            targets: ["RTVIClientIOSGeminiLiveWebSocket"]),
    ],
    dependencies: [
        // Local dependency
//        .package(path: "../rtvi-client-ios"),
         .package(url: "https://github.com/pipecat-ai/pipecat-client-ios.git", from: "0.3.0"),
        // TODO: we can remove this once we're done with the prototyping. Useful to have it here to refer to types
        .package(url: "https://github.com/daily-co/daily-client-ios.git", from: "0.23.0")
    ],
    targets: [
        .target(
            name: "RTVIClientIOSGeminiLiveWebSocket",
            dependencies: [
                .product(name: "PipecatClientIOS", package: "pipecat-client-ios"),
                // TODO: we can remove this once we're done with the prototyping. Useful to have it here to refer to types
                .product(name: "Daily", package: "daily-client-ios")
            ]),
        .testTarget(
            name: "RTVIClientIOSGeminiLiveWebSocketTests",
            dependencies: ["RTVIClientIOSGeminiLiveWebSocket"]),
    ]
)
