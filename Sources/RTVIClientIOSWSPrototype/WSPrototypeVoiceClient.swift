import Foundation
import RTVIClientIOS

/// An RTVI client. Connects to a WebSocket backend and handles bidirectional audio streaming
@MainActor
public class WSPrototypeVoiceClient: RTVIClient {
    
    public init(baseUrl:String? = nil, options: RTVIClientOptions) {
        super.init(baseUrl: baseUrl, transport: WSPrototypeTransport.init(options: options), options: options)
    }
    
}
