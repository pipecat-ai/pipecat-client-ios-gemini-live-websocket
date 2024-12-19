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
    
    func connectionDidFinishModelSetup(_: GeminiLiveWebSocketConnection) {
        // If this happens *before* we've entered the connected state, first pass through that state
        if _state == .connecting {
            self.setState(state: .connected)
            self.delegate?.onConnected()
        }
        
        // Synthesize (i.e. fake) an RTVI-style "bot ready" response from the server
        // TODO: can we do better with this BotReadyData?
        let botReadyData = BotReadyData(version: "n/a", config: [])
        onMessage?(.init(
            type: RTVIMessageInbound.MessageType.BOT_READY,
            data: String(data: try! JSONEncoder().encode(botReadyData), encoding: .utf8),
            id: String(UUID().uuidString.prefix(8))
        ))
    }
    
    func connection(
        _: GeminiLiveWebSocketConnection,
        didReceiveModelAudioBytes audioBytes: Data
    ) {
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
        
        // go to connected state
        // (unless we've already leaped ahead to the ready state - see connectionDidFinishModelSetup())
        if _state == .connecting {
            self.setState(state: .connected)
            self.delegate?.onConnected()
        }
    }
    
    public func disconnect() async throws {
        // stop websocket connection
        connection.disconnect()
        
        // stop audio input
        // TODO: later. do we need to set mic to muted or something? no, we probably should keep mic as showing "on"...right? check Daily implementation.
        
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
            let messagesArgument = data.arguments?.first { $0.name == "messages" }
            if let messages = messagesArgument?.value.toMessagesArray() {
                Task {
                    // Send messages to LLM
                    for message in messages {
                        try await connection.sendMessage(message: message)
                    }
                    // Synthesize (i.e. fake) an RTVI-style action response from the server
                    let id = message.id
                    onMessage?(.init(
                        type: RTVIMessageInbound.MessageType.ACTION_RESPONSE,
                        data: String(data: try JSONEncoder().encode(ActionResponse.init(result: .boolean(true))), encoding: .utf8),
                        id: message.id
                    ))
                    // TODO: check whether system messages are supported, and whether multiple messages can be enqueued at once
                }
            }
        } else {
            if message.type == RTVIMessageOutbound.MessageType.ACTION {
                logOperationNotSupported("\(#function) of type 'action' (except for append_to_messages)")
            } else {
                logOperationNotSupported("\(#function) of type '\(message.type)'")
            }
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

