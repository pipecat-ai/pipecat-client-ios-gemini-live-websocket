import Foundation
import RTVIClientIOS

class GeminiLiveWebSocketConnection: NSObject, URLSessionWebSocketDelegate {
    
    // MARK: - Public
    
    struct Options {
        let apiKey: String
        let initialMessages: [WebSocketMessages.Outbound.TextInput]
        let generationConfig: Value?
    }
    
    protocol Delegate: AnyObject {
        func connection(
            _: GeminiLiveWebSocketConnection,
            didReceiveModelAudioBytes audioBytes: Data
        )
    }
    
    public weak var delegate: Delegate? = nil
    
    init(options: Options) {
        self.options = options
    }
    
    func connect() async throws {
        guard socket == nil else {
            assertionFailure()
            return
        }
        
        // Create web socket
        let urlSession = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: OperationQueue()
        )
        let host = "preprod-generativelanguage.googleapis.com"
        let url = URL(string: "wss://\(host)/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(options.apiKey)")
        let socket = urlSession.webSocketTask(with: url!)
        self.socket = socket
        
        // Connect
        // NOTE: at this point no need to wait for socket to open to start sending events
        socket.resume()
        
        // Send initial setup message
        let model = "models/gemini-2.0-flash-exp" // TODO: make this configurable at some point
        try await sendMessage(
            message: WebSocketMessages.Outbound.Setup(
                model: model,
                generationConfig: options.generationConfig
            )
        )
        try Task.checkCancellation()
        
        // Send initial context messages
        for message in options.initialMessages {
            try await sendMessage(message: message)
            try Task.checkCancellation()
        }
        
        // Listen for server messages
        Task {
            while true {
                let decoder = JSONDecoder()
                
                let message = try await socket.receive()
                try Task.checkCancellation()
                
                switch message {
                case .data(let data):
                    // TODO: remove after testing
                    print("[pk] received server message: \(String(data: data, encoding: .utf8))")
                    do {
                        let serverMessage = try decoder.decode(
                            WebSocketMessages.Inbound.AudioOutput.self,
                            from: data
                        )
                        if let audioBytes = serverMessage.audioBytes() {
                            delegate?.connection(
                                self,
                                didReceiveModelAudioBytes: audioBytes
                            )
                        }
                    } catch {
                        continue
                    }
                case .string(let string):
                    // TODO: better logging
                    print("[pk] received server message of unexpected type: \(string)")
                    continue
                }
            }
        }
    }
    
    func sendUserAudio(_ audio: Data) async throws {
        // TODO: first check if we've successfully run through connect()?
        try await sendMessage(
            message: WebSocketMessages.Outbound.AudioInput(audio: audio)
        )
    }
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print("[pk] web socket opened!")
    }
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        print("[pk] web socket closed! close code \(closeCode)")
    }
    
    // MARK: - Private
    
    private let options: GeminiLiveWebSocketConnection.Options
    private var socket: URLSessionWebSocketTask?
    
    private func sendMessage(message: Encodable) async throws {
        let encoder = JSONEncoder()
        
        // TODO: remove after testing
        let messageString = try! String(
            data: encoder.encode(message),
            encoding: .utf8
        )!
        print("[pk] sending message: \(messageString)")
        
        try await socket?.send(
            .string(
                String(data: encoder.encode(message), encoding: .utf8)!
            )
        )
    }
}
