import Foundation

struct GeminiWebSocketConnectionOptions {
    // TODO: this
}

class GeminiWebSocketConnection: NSObject, URLSessionWebSocketDelegate {
    
    // MARK: - Public
    
    init(options: GeminiWebSocketConnectionOptions) {
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
        let apiKey = "AIzaSyDSytBQHiU8XnOxLXWQpKnJRqhjfxUWU5U"
        let url = URL(string: "wss://\(host)/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)")
        let socket = urlSession.webSocketTask(with: url!)
        self.socket = socket
        
        // Connect
        // NOTE: at this point no need to wait for socket to open to start sending events
        socket.resume()
        
        // Send initial setup message
        let model = "models/gemini-2.0-flash-exp"
        try await sendMessage(message: SetupMessage(model: model))
        try Task.checkCancellation()
        
        // TODO: remove after testing
        // Send initial text input
        let initialText = "Hi, who are you?"
        try await sendMessage(message: TextInputMessage(text: initialText))
        try Task.checkCancellation()
        
        // Listen for server messages
        Task {
            while true {
                let decoder = JSONDecoder()
                
                let message = try await socket.receive()
                try Task.checkCancellation()
                
                switch message {
                case .data(let data):
                    print("[pk] received server message: \(String(data: data, encoding: .utf8))")
                    do {
                        let serverMessage = try decoder.decode(
                            ModelAudioMessage.self,
                            from: data
                        )
                        // TODO: call delegate or something
                        print("[pk] received model audio!")
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
    
    private let options: GeminiWebSocketConnectionOptions
    private var socket: URLSessionWebSocketTask?
    
    private func sendMessage(message: Encodable) async throws {
        let encoder = JSONEncoder()
        
        let messageString = try! String(
            data: encoder.encode(message),
            encoding: .utf8
        )!
        // TODO: remove after testing
        print("[pk] sending message: \(messageString)")
        
        try await socket?.send(
            .string(
                String(data: encoder.encode(message), encoding: .utf8)!
            )
        )
    }
}
