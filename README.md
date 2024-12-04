# Daily Real-Time Voice Inference iOS SDK

[RTVI-AI](https://github.com/rtvi-ai/) is an open standard for Real-Time Voice [and Video] Inference.

This library exports a VoiceClient that has the [Daily](https://www.daily.co/) transport associated.

## Install

To depend on the client package, you can add this package via Xcode's package manager using the URL of this git repository directly, or you can declare your dependency in your `Package.swift`:

```swift
.package(url: "https://github.com/rtvi-ai/rtvi-client-ios-daily.git", from: "0.1.0"),
```

and add `"RTVIClientIOSDaily"` to your application/library target, `dependencies`, e.g. like this:

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "RTVIClientIOSDaily", package: "rtvi-client-ios-daily")
],
```

## Quick Start

Instantiate a `VoiceClient` instance, wire up the bot's audio, and start the conversation:

```swift
let clientConfigOptions = [
    ServiceConfig(
        service: "llm",
        options: [
            Option(name: "model", value: JSONValue.string("meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo")),
            Option(name: "messages", value: JSONValue.array([
                JSONValue.object([
                    "role" : JSONValue.string("system"),
                    "content": JSONValue.string("You are a assistant called ExampleBot. You can ask me anything. Keep responses brief and legible. Introduce yourself first.")
                ])
            ]))
        ]
    ),
    ServiceConfig(
        service: "tts",
        options: [
            Option(name: "voice", value: JSONValue.string("79a125e8-cd45-4c13-8a67-188112f4dd22"))
        ]
    )
]
let options = VoiceClientOptions.init(
    services: ["llm": "together", "tts": "cartesia"],
    config: clientConfigOptions
)

let defaultBackendURL = "http://192.168.1.23:7860/"
self.backendURL = defaultBackendURL

let rtviClientIOS = DailyVoiceClient.init(baseUrl: defaultBackendURL, options: options)

try await rtviClientIOS.start()
```

## References
- [RTVI-AI overview](https://github.com/rtvi-ai/).
- [RTVI-AI reference docs](https://rtvi.mintlify.app/api-reference/introduction).
- [rtvi-client-ios SDK docs](https://rtvi-client-ios-docs.vercel.app/RTVIClientIOS/documentation/rtviclientios).
- [rtvi-client-ios-daily SDK docs](https://rtvi-client-ios-docs.vercel.app/RTVIClientIOSDaily/documentation/rtviclientiosdaily).

## Contributing

We are welcoming contributions to this project in form of issues and pull request. For questions about RTVI head over to the [Pipecat discord server](https://discord.gg/pipecat) and check the [#rtvi](https://discord.com/channels/1239284677165056021/1265086477964935218) channel.
