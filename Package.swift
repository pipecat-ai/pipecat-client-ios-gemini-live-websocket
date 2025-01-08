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
//        .package(path: "../pipecat-client-ios"),
         .package(url: "https://github.com/pipecat-ai/pipecat-client-ios.git", from: "0.3.1"),
    ],
    targets: [
        .target(
            name: "RTVIClientIOSGeminiLiveWebSocket",
            dependencies: [
                .product(name: "PipecatClientIOS", package: "pipecat-client-ios")
            ]),
        .testTarget(
            name: "RTVIClientIOSGeminiLiveWebSocketTests",
            dependencies: ["RTVIClientIOSGeminiLiveWebSocket"]),
    ]
)
