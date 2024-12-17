import Foundation
import RTVIClientIOS

/// An RTVI client. Connects to a Gemini Live WebSocket backend and handles bidirectional audio streaming
@MainActor
public class GeminiLiveWebSocketVoiceClient: RTVIClient {
    
    public init(options: RTVIClientOptions) {
        super.init(baseUrl: nil, transport: GeminiLiveWebSocketTransport.init(options: options), options: options)
    }
}
