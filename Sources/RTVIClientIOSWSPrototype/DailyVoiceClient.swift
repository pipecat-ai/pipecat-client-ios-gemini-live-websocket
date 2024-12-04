import Foundation
import RTVIClientIOS

/// An RTVI client. Connects to a Daily Bots backend and handles bidirectional audio and video streaming
@MainActor
public class DailyVoiceClient: RTVIClient {
    
    public init(baseUrl:String? = nil, options: RTVIClientOptions) {
        super.init(baseUrl: baseUrl, transport: DailyTransport.init(options: options), options: options)
    }
    
}
