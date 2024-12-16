import Foundation
import RTVIClientIOS

/// An RTVI client. Connects to a Gemini Live WebSocket backend and handles bidirectional audio streaming
@MainActor
public class WSPrototypeVoiceClient: RTVIClient {
    
    public init(baseUrl:String? = nil, options: RTVIClientOptions) {
        super.init(baseUrl: baseUrl, transport: GeminiLiveWebSocketTransport.init(options: options), options: options)
    }
}
