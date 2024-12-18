import Foundation
import RTVIClientIOS
import Daily
import OSLog

/// An RTVI transport to connect with the Gemini Live WebSocket backend.
public class GeminiLiveWebSocketTransport: Transport, GeminiLiveWebSocketConnection.Delegate {
    
    // MARK: - Public
    
    /// Voice client delegate (used directly by user's code)
    public var delegate: RTVIClientIOS.RTVIClientDelegate?
    
    /// RTVI inbound message handler (for sending RTVI-style messages to voice client code to handle)
    public var onMessage: ((RTVIClientIOS.RTVIMessageInbound) -> Void)?
    
    public required init(options: RTVIClientIOS.RTVIClientOptions) {
        self.options = options
        connection = GeminiLiveWebSocketConnection(options: options.webSocketConnectionOptions)
        connection.delegate = self
    }
    
    func connection(
        _: GeminiLiveWebSocketConnection,
        didReceiveModelAudioBytes audioBytes: Data
    ) {
        print("[pk] received model audio! (length: \(audioBytes.count))")
        audioPlayer.enqueueBytes(audioBytes)
    }
    
    public func initDevices() async throws {
        self.setState(state: .initializing)
        
        // wire up audio input
        wireUpAudioInput()
        
        self.setState(state: .initialized)
    }
    
    public func release() {
        // stop audio input
        audioRecorder.stop()
    }
    
    public func connect(authBundle: RTVIClientIOS.AuthBundle?) async throws {
        self.setState(state: .connecting)
        
        // start audio player
        try audioPlayer.start()
        
        // start connecting
        try await connection.connect()
        
        // start audio input if needed
        if options.enableMic {
            try audioRecorder.resume()
        }
        
        self.setState(state: .connected)
        self.delegate?.onConnected()
    }
    
    public func disconnect() async throws {
        // stop websocket connection
        // TODO: later
        
        // stop audio player
        // TODO: later
        
        setState(state: .disconnected)
    }
    
    public func getAllMics() -> [RTVIClientIOS.MediaDeviceInfo] {
        // TODO: later
        return []
    }
    
    public func getAllCams() -> [RTVIClientIOS.MediaDeviceInfo] {
        logOperationNotSupported(#function)
        return []
    }
    
    public func updateMic(micId: RTVIClientIOS.MediaDeviceId) async throws {
        // TODO: later
    }
    
    public func updateCam(camId: RTVIClientIOS.MediaDeviceId) async throws {
        logOperationNotSupported(#function)
    }
    
    public func selectedMic() -> RTVIClientIOS.MediaDeviceInfo? {
        // TODO: later
        return nil
    }
    
    public func selectedCam() -> RTVIClientIOS.MediaDeviceInfo? {
        logOperationNotSupported(#function)
        return nil
    }
    
    public func enableMic(enable: Bool) async throws {
        if enable {
            try audioRecorder.resume()
        } else {
            audioRecorder.pause()
        }
    }
    
    public func enableCam(enable: Bool) async throws {
        logOperationNotSupported(#function)
    }
    
    public func isCamEnabled() -> Bool {
        logOperationNotSupported(#function)
        return false
    }
    
    public func isMicEnabled() -> Bool {
        return audioRecorder.isRecording
    }
    
    public func sendMessage(message: RTVIClientIOS.RTVIMessageOutbound) throws {
        if let data = message.decodeActionData(), data.service == "llm" && data.action == "append_to_messages" {
            // TODO: remove log
            print("append_to_messages detected!")
            // TODO: refactor?
            var messages: [WebSocketMessages.Outbound.TextInput] = []
            let messagesArgument = data.arguments?.first { $0.name == "messages" }
            if case let .array(messageValues) = messagesArgument?.value {
                for messageValue in messageValues {
                    if case let .object(messageObject) = messageValue {
                        let roleValue = messageObject["role"]
                        let contentValue = messageObject["content"]
                        if case let .string(role) = roleValue {
                            if case let .string(content) = contentValue {
                                messages.append(.init(text: content, role: role))
                            }
                        }
                    }
                }
            }
            Task {
                for message in messages {
                    try await connection.sendMessage(message: message)
                }
                // TODO: send faked "response" from server back to client to complete the action
                // TODO: check whether system messages are supported, and whether multiple messages can be enqueued at once
            }
        } else {
            logOperationNotSupported("\(#function), except for append_to_messages actions")
        }
    }
    
    public func state() -> RTVIClientIOS.TransportState {
        self._state
    }
    
    public func setState(state: RTVIClientIOS.TransportState) {
        self._state = state
        // TODO: remove when done debugging (actually maybe already not necessary)
        print("[pk] new state: \(state)")
        self.delegate?.onTransportStateChanged(state: self._state)
    }
    
    public func isConnected() -> Bool {
        return [.connected, .ready].contains(self._state)
    }
    
    public func tracks() -> RTVIClientIOS.Tracks? {
        // TODO: later
        return .init(
            local: .init(
                audio: nil,
                video: nil
            ),
            bot: nil
        )
    }
    
    public func expiry() -> Int? {
        // TODO: later
        return nil
    }
    
    // MARK: - Private
    
    private let options: RTVIClientOptions
    private var _state: TransportState = .disconnected
    private let connection: GeminiLiveWebSocketConnection
    private let audioPlayer = AudioPlayer()
    private let audioRecorder = AudioRecorder()
    
    private func wireUpAudioInput() {
        Task {
            for await audio in audioRecorder.streamAudio() {
                do {
                    try await connection.sendUserAudio(audio)
                } catch {
                    // TODO: better error handling
                    print("[pk] send user audio failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func logOperationNotSupported(_ operationName: String) {
        Logger.shared.warn("\(operationName) not supported")
    }
}

