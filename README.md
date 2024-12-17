# Pipecat iOS SDK with Gemini Multimodal Live WebSocket Transport

This library exports a voice client that is bundled with a transport layer that talks directly to the [Gemini Multimodal Live WebSocket API](https://ai.google.dev/gemini-api/docs/models/gemini-v2).

## Install

To depend on the client package, you can add this package via Xcode's package manager using the URL of this git repository directly, or you can declare your dependency in your `Package.swift`:

```swift
.package(url: "https://github.com/pipecat-ai/pipecat-client-ios-gemini-live-websocket.git", from: "0.3.1"),
```

and add `"PipecatClientIOSGeminiLiveWebSocket"` to your application/library target, `dependencies`, e.g. like this:

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "PipecatClientIOSGeminiLiveWebSocket", package: "pipecat-client-ios-gemini-live-websocket")
],
```

## Quick Start

Instantiate a `VoiceClient` instance, wire up the bot's audio, and start the conversation:

```swift
let client = GeminiLiveWebSocketVoiceClient(
    options: .init(
        params: .init(config: [
            .init(
                service: "llm",
                options: [
                    .init(name: "api_key", value: .string(""))
                ]
            )
        ])
    )
)
try await client.start()
```

## Contributing

We are welcoming contributions to this project in form of issues and pull request. For questions about Pipecat head over to the [Pipecat discord server](https://discord.gg/pipecat).
