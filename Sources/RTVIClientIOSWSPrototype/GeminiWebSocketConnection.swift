import Foundation

// TODO: split types into separate files?

// Outbound messages

private struct SetupMessage: Encodable {
    var setup: Setup
    
    struct Setup: Encodable {
        var model: String
    }
    
    init(model: String) {
        self.setup = .init(model: model)
    }
}

private struct TextInputMessage: Encodable {
    var clientContent: ClientContent
    
    struct ClientContent: Encodable {
        var turns: [Turn]
        var turnComplete = true
        
        struct Turn: Encodable {
            var role = "USER"
            var parts: [Text]
            
            struct Text: Encodable {
                var text: String
            }
        }
    }
    
    init(text: String) {
        self.clientContent = .init(
            turns: [
                .init(parts: [.init(text: text)])
            ]
        )
    }
}

enum GeminiWebSocketConnectionError: Error {
}

struct GeminiWebSocketConnectionOptions {}

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
        socket = urlSession.webSocketTask(with: url!)
        
        // Connect
        // NOTE: at this point no need to wait for socket to open to start sending events
        socket?.resume()
        
        // Send initial setup message
        let model = "models/gemini-2.0-flash-exp"
        try await sendMessage(message: SetupMessage(model: model))
        try Task.checkCancellation()
        
        // TODO: remove after testing
        // Send initial text input
        let initialText = "Hi, who are you?"
        try await sendMessage(message: TextInputMessage(text: initialText))
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
