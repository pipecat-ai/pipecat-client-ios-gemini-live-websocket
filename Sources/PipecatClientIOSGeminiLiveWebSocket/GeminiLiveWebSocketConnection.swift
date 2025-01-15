import Foundation
import PipecatClientIOS

protocol GeminiLiveWebSocketConnectionDelegate: AnyObject {
    func connectionDidFinishModelSetup(
        _: GeminiLiveWebSocketConnection
    )
    func connection(
        _: GeminiLiveWebSocketConnection,
        didReceiveModelAudioBytes audioBytes: Data
    )
    func connectionDidDetectUserInterruption(_: GeminiLiveWebSocketConnection)
}

class GeminiLiveWebSocketConnection: NSObject, URLSessionWebSocketDelegate {
    
    // MARK: - Public
    
    struct Options {
        let apiKey: String
        let initialMessages: [WebSocketMessages.Outbound.TextInput]
        let generationConfig: Value?
    }
    
    public weak var delegate: GeminiLiveWebSocketConnectionDelegate? = nil
    
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
        let model = "models/gemini-2.0-flash-exp" // TODO: make this configurable someday
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
                do {
                    let decoder = JSONDecoder()
                    
                    let message = try await socket.receive()
                    try Task.checkCancellation()
                    
                    switch message {
                    case .data(let data):
//                        print("received server message: \(String(data: data, encoding: .utf8)?.prefix(50))")
                        
                        // Check for setup complete message
                        let setupCompleteMessage = try? decoder.decode(
                            WebSocketMessages.Inbound.SetupComplete.self,
                            from: data
                        )
                        if let setupCompleteMessage {
                            delegate?.connectionDidFinishModelSetup(self)
                            continue
                        }
                        
                        // Check for audio output message
                        let audioOutputMessage = try? decoder.decode(
                            WebSocketMessages.Inbound.AudioOutput.self,
                            from: data
                        )
                        if let audioOutputMessage, let audioBytes = audioOutputMessage.audioBytes() {
                            delegate?.connection(
                                self,
                                didReceiveModelAudioBytes: audioBytes
                            )
                        }
                        
                        // Check for interrupted message
                        let interruptedMessage = try? decoder.decode(
                            WebSocketMessages.Inbound.Interrupted.self,
                            from: data
                        )
                        if let interruptedMessage {
                            delegate?.connectionDidDetectUserInterruption(self)
                            continue
                        }
                        continue
                    case .string(let string):
                        Logger.shared.warn("Received server message of unexpected type: \(string)")
                        continue
                    }
                } catch {
                    // Socket is known to be closed (set to nil), so break out of the socket receive loop
                    if self.socket == nil {
                        break
                    }
                    // Otherwise wait a smidge and loop again
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
        }
        
        // We finished all the connect() steps
        didFinishConnect = true
    }
    
    func sendUserAudio(_ audio: Data) async throws {
        // Only send user audio once the connect() steps (which includes model setup) have finished
        if !didFinishConnect {
            return
        }
        try await sendMessage(
            message: WebSocketMessages.Outbound.AudioInput(audio: audio)
        )
    }
    
    func sendMessage(message: Encodable) async throws {
        let encoder = JSONEncoder()
        
        let messageString = try! String(
            data: encoder.encode(message),
            encoding: .utf8
        )!
//        print("sending message: \(messageString.prefix(50))")
        try await socket?.send(.string(messageString))
    }
    
    func disconnect() {
        // This will trigger urlSession(_:webSocketTask:didCloseWith:reason:), where we will nil out socket and thus cause the socket receive loop to end
        socket?.cancel(with: .normalClosure, reason: nil)
    }
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
//        print("web socket opened!")
    }
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
//        print("web socket closed! close code \(closeCode)")
        socket = nil
        didFinishConnect = false
    }
    
    // MARK: - Private
    
    private let options: GeminiLiveWebSocketConnection.Options
    private var socket: URLSessionWebSocketTask?
    private var didFinishConnect = false
}
