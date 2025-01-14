import Foundation
import PipecatClientIOS
import OSLog

/// An RTVI transport to connect with the Gemini Live WebSocket backend.
public class GeminiLiveWebSocketTransport: Transport {
    
    // MARK: - Public
    
    /// Voice client delegate (used directly by user's code)
    public weak var delegate: PipecatClientIOS.RTVIClientDelegate?
    
    /// RTVI inbound message handler (for sending RTVI-style messages to voice client code to handle)
    public var onMessage: ((PipecatClientIOS.RTVIMessageInbound) -> Void)?
    
    public required init(options: PipecatClientIOS.RTVIClientOptions) {
        self.options = options
        connection = GeminiLiveWebSocketConnection(options: options.webSocketConnectionOptions)
        connection.delegate = self
        audioPlayer.delegate = self
        audioRecorder.delegate = self
        audioManager.delegate = self
        logUnsupportedOptions()
    }
    
    public func initDevices() async throws {
        if (self.devicesInitialized) {
            // There is nothing to do in this case
            return
        }
        
        self.setState(state: .initializing)
        
        // start managing audio device configuration
        audioManager.startManagingIfNecessary()
        
        // report initial available & selected devices
        self.delegate?.onAvailableMicsUpdated(mics: self.getAllMics());
        self._selectedMic = self.selectedMic()
        self.delegate?.onMicUpdated(mic: self._selectedMic)
        
        // hook up audio input
        hookUpAudioInputStream()
        
        self.setState(state: .initialized)
        self.devicesInitialized = true
    }
    
    public func release() {
        // stop audio input and terminate stream
        audioRecorder.stop()
        audioRecorder.terminateAudioStream()
        
        // stop audio player
        audioPlayer.stop()
        
        // stop managing audio device configuration
        audioManager.stopManaging()
    }
    
    public func connect(authBundle: PipecatClientIOS.AuthBundle?) async throws {
        self.setState(state: .connecting)
        
        // start audio player
        try audioPlayer.start()
        
        // start audio input if needed
        // this is done before connecting WebSocket to guarantee that by the time we transition to the .connected state isMicEnabled() reflects the truth
        if options.enableMic {
            try audioRecorder.resume()
        }
        
        // start connecting
        try await connection.connect()
        
        // initialize tracks (which are just dummy values)
        updateTracks(
            localAudio: .init(id: UUID().uuidString),
            botAudio: .init(id: UUID().uuidString)
        )
        
        // go to connected state
        // (unless we've already leaped ahead to the ready state - see connectionDidFinishModelSetup())
        if _state == .connecting {
            self.setState(state: .connected)
        }
    }
    
    public func disconnect() async throws {
        // stop websocket connection
        connection.disconnect()
        
        // stop audio input
        // (why not just pause it? to avoid problems in case the user forgets to call release() before instantiating a new voice client)
        audioRecorder.stop()
        
        // stop audio player
        audioPlayer.stop()
        
        // clear tracks (which are just dummy values)
        updateTracks(
            localAudio: nil,
            botAudio: nil
        )
        
        setState(state: .disconnected)
    }
    
    public func getAllMics() -> [PipecatClientIOS.MediaDeviceInfo] {
        audioManager.availableDevices.map { $0.toRtvi() }
    }
    
    public func getAllCams() -> [PipecatClientIOS.MediaDeviceInfo] {
        logOperationNotSupported(#function)
        return []
    }
    
    public func updateMic(micId: PipecatClientIOS.MediaDeviceId) async throws {
        audioManager.preferredAudioDevice = .init(deviceID: micId.id)
        // Changing preferred audio device probably changed actual audio device in use
        updateSelectedMicIfNeeded()
    }
    
    public func updateCam(camId: PipecatClientIOS.MediaDeviceId) async throws {
        logOperationNotSupported(#function)
    }
    
    public func selectedMic() -> PipecatClientIOS.MediaDeviceInfo? {
        audioManager.availableDevices.first { $0.deviceID == audioManager.audioDevice.deviceID }?.toRtvi()
    }
    
    public func selectedCam() -> PipecatClientIOS.MediaDeviceInfo? {
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
    
    public func sendMessage(message: PipecatClientIOS.RTVIMessageOutbound) throws {
        if let data = message.decodeActionData(), data.service == "llm" && data.action == "append_to_messages" {
            let messagesArgument = data.arguments?.first { $0.name == "messages" }
            if let messages = messagesArgument?.value.toTextInputWebSocketMessagesArray() {
                Task {
                    // Send messages to LLM
                    for message in messages {
                        try await connection.sendMessage(message: message)
                    }
                    // Synthesize (i.e. fake) an RTVI-style action response from the server
                    onMessage?(.init(
                        type: RTVIMessageInbound.MessageType.ACTION_RESPONSE,
                        data: String(data: try JSONEncoder().encode(ActionResponse.init(result: .boolean(true))), encoding: .utf8),
                        id: message.id
                    ))
                }
            }
        } else {
            if message.type == RTVIMessageOutbound.MessageType.ACTION {
                logOperationNotSupported("\(#function) of type 'action' (except for 'append_to_messages')")
            } else {
                logOperationNotSupported("\(#function) of type '\(message.type)'")
            }
            // Tell RTVIClient that sendMessage() has failed so the user's completion handler can run
            onMessage?(.init(
                type: RTVIMessageInbound.MessageType.ERROR_RESPONSE,
                data: "", // passing nil causes a crash
                id: message.id
            ))
        }
    }
    
    public func state() -> PipecatClientIOS.TransportState {
        self._state
    }
    
    public func setState(state: PipecatClientIOS.TransportState) {
        let previousState = self._state
        
        self._state = state
        self.delegate?.onTransportStateChanged(state: self._state)
        
        // Fire delegate methods as needed
        if state != previousState {
            if state == .connected {
                self.delegate?.onConnected()
                // New bot participant id each time we connect
                connectedBotParticipant = Participant(
                    id: ParticipantId(id: UUID().uuidString),
                    name: connectedBotParticipant.name,
                    local: connectedBotParticipant.local
                )
                self.delegate?.onParticipantJoined(participant: connectedBotParticipant)
                self.delegate?.onBotConnected(participant: connectedBotParticipant)
            }
            if state == .disconnected {
                self.delegate?.onParticipantLeft(participant: connectedBotParticipant)
                self.delegate?.onBotDisconnected(participant: connectedBotParticipant)
                self.delegate?.onDisconnected()
            }
        }
    }
    
    public func isConnected() -> Bool {
        return [.connected, .ready].contains(self._state)
    }
    
    public func tracks() -> PipecatClientIOS.Tracks? {
        return .init(
            local: .init(
                audio: localAudioTrackID,
                video: nil // video not yet supported
            ),
            bot: .init(
                audio: botAudioTrackID,
                video: nil // video not yet supported
            )
        )
    }
    
    public func expiry() -> Int? {
        return nil
    }
    
    // MARK: - Private
    
    private let options: RTVIClientOptions
    private var _state: TransportState = .disconnected
    private let connection: GeminiLiveWebSocketConnection
    private let audioManager = AudioManager()
    private let audioPlayer = AudioPlayer()
    private let audioRecorder = AudioRecorder()
    private var connectedBotParticipant = Participant(
        id: ParticipantId(id: UUID().uuidString),
        name: "Gemini Multimodal Live",
        local: false
    )
    private var devicesInitialized: Bool = false
    private var _selectedMic: MediaDeviceInfo?
    
    // audio tracks aren't directly useful to the user; they're just dummy values for API completeness
    private var localAudioTrackID: MediaTrackId?
    private var botAudioTrackID: MediaTrackId?
    
    private func hookUpAudioInputStream() {
        Task {
            for await audio in audioRecorder.streamAudio() {
                do {
                    try await connection.sendUserAudio(audio)
                } catch {
                    Logger.shared.warn("Send user audio failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func logUnsupportedOptions() {
        if options.enableCam {
            logOperationNotSupported("enableCam option")
        }
        if !options.services.isEmpty {
            logOperationNotSupported("services option")
        }
        if options.customBodyParams != nil || options.params.requestData != nil {
            logOperationNotSupported("params.requestData/customBodyParams option")
        }
        if options.customHeaders != nil || !options.params.headers.isEmpty {
            logOperationNotSupported("params.headers/customBodyParams option")
        }
        let config = options.config ?? options.params.config
        if config.contains { $0.service != "llm" } {
            logOperationNotSupported("config for service other than 'llm'")
        }
        if let llmConfig = config.llmConfig {
            let supportedLlmConfigOptions = ["api_key", "initial_messages", "generation_config"]
            if llmConfig.options.contains { !supportedLlmConfigOptions.contains($0.name) } {
                logOperationNotSupported("'llm' service config option other than \(supportedLlmConfigOptions.joined(separator: ", "))")
            }
        }
    }
    
    private func logOperationNotSupported(_ operationName: String) {
        Logger.shared.warn("\(operationName) not supported")
    }
    
    private func updateSelectedMicIfNeeded() {
        if self.selectedMic() == self._selectedMic {
            return
        }
        self._selectedMic = self.selectedMic()
        self.delegate?.onMicUpdated(mic: self._selectedMic)
        do {
            try audioPlayer.adaptToDeviceChange()
        } catch {
            Logger.shared.error("Audio player failed to adapt to device change")
        }
        do {
            try audioRecorder.adaptToDeviceChange()
        } catch {
            Logger.shared.error("Audio recorder failed to adapt to device change")
        }
    }
    
    // updates tracks.
    // note that they're not directly useful to the user; they're just dummy values for API completeness.
    private func updateTracks(localAudio: MediaTrackId?, botAudio: MediaTrackId?) {
        if localAudio == localAudioTrackID && botAudio == botAudioTrackID {
            return
        }
        localAudioTrackID = localAudio
        botAudioTrackID = botAudio
        delegate?.onTracksUpdated(tracks: tracks()!)
    }
}

// MARK: - GeminiLiveWebSocketConnection.Delegate

extension GeminiLiveWebSocketTransport: GeminiLiveWebSocketConnectionDelegate {
    func connectionDidFinishModelSetup(_: GeminiLiveWebSocketConnection) {
        // If this happens *before* we've entered the connected state, first pass through that state
        if _state == .connecting {
            self.setState(state: .connected)
        }
        
        // Synthesize (i.e. fake) an RTVI-style "bot ready" response from the server
        // TODO: can we fill in more meaningful BotReadyData someday?
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
    
    func connectionDidDetectUserInterruption(_: GeminiLiveWebSocketConnection) {
        audioPlayer.clearEnqueuedBytes()
        delegate?.onUserStartedSpeaking()
    }
}

// MARK: - AudioPlayer.Delegate

extension GeminiLiveWebSocketTransport: AudioPlayerDelegate {
    func audioPlayerDidStartPlayback(_ audioPlayer: AudioPlayer) {
        delegate?.onBotStartedSpeaking(participant: connectedBotParticipant)
    }
    
    func audioPlayerDidFinishPlayback(_ audioPlayer: AudioPlayer) {
        delegate?.onBotStoppedSpeaking(participant: connectedBotParticipant)
    }
    
    func audioPlayer(_ audioPlayer: AudioPlayer, didGetAudioLevel audioLevel: Float) {
        delegate?.onRemoteAudioLevel(level: audioLevel, participant: connectedBotParticipant)
    }
}

// MARK: - AudioRecorder.Delegate

extension GeminiLiveWebSocketTransport: AudioRecorderDelegate {
    func audioRecorder(_ audioPlayer: AudioRecorder, didGetAudioLevel audioLevel: Float) {
        delegate?.onUserAudioLevel(level: audioLevel)
    }
}

// MARK: - AudioManagerDelegate

extension GeminiLiveWebSocketTransport: AudioManagerDelegate {
    func audioManagerDidChangeDevices(_ audioManager: AudioManager) {
        // Available devices changed
        delegate?.onAvailableMicsUpdated(mics: audioManager.availableDevices.map { $0.toRtvi() })
        
        // Current audio device *may* have also changed as side-effect of available devices changing
        updateSelectedMicIfNeeded()
    }
}
