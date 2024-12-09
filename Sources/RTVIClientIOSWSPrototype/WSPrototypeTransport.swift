import Foundation
import RTVIClientIOS
import Daily

/// An RTVI transport to connect with a WebSocket backend.
public class WSPrototypeTransport: Transport, GeminiWebSocketConnectionDelegate {
    
    // MARK: - Public
    
    /// Voice client delegate (used directly by user's code)
    public var delegate: RTVIClientIOS.RTVIClientDelegate?
    
    /// RTVI inbound message handler (for sending RTVI-style messages to voice client code to handle)
    public var onMessage: ((RTVIClientIOS.RTVIMessageInbound) -> Void)?
    
    public required init(options: RTVIClientIOS.RTVIClientOptions) {
        self.options = options
        // TODO: initiatlize GeminiWebSocketConnectionOptions from RTVIClientOptions
        connection = GeminiWebSocketConnection(options: .init())
        connection.delegate = self
    }
    
    func connection(
        _: GeminiWebSocketConnection,
        didReceiveModelAudioBytes audioBytes: Data
    ) {
        print("[pk] received model audio! (length: \(audioBytes.count))")
    }
    
    // MARK: - Private
    
    private let options: RTVIClientOptions
    private var _state: TransportState = .disconnected
    private let connection: GeminiWebSocketConnection
    
    public func initDevices() async throws {
        self.setState(state: .initializing)
        // TODO: later
        self.setState(state: .initialized)
    }
    
    public func release() {
        // TODO: later
    }
    
    public func connect(authBundle: RTVIClientIOS.AuthBundle) async throws {
        self.setState(state: .connecting)
        try await connection.connect()
        self.setState(state: .connected)
    }
    
    public func disconnect() async throws {
        // TODO: later
    }
    
    public func getAllMics() -> [RTVIClientIOS.MediaDeviceInfo] {
        // TODO: later
        return []
    }
    
    public func getAllCams() -> [RTVIClientIOS.MediaDeviceInfo] {
        // TODO: later
        return []
    }
    
    public func updateMic(micId: RTVIClientIOS.MediaDeviceId) async throws {
        // TODO: later
    }
    
    public func updateCam(camId: RTVIClientIOS.MediaDeviceId) async throws {
        // TODO: later
    }
    
    public func selectedMic() -> RTVIClientIOS.MediaDeviceInfo? {
        // TODO: later
        return nil
    }
    
    public func selectedCam() -> RTVIClientIOS.MediaDeviceInfo? {
        // TODO: later
        return nil
    }
    
    public func enableMic(enable: Bool) async throws {
        // TODO: later
    }
    
    public func enableCam(enable: Bool) async throws {
        // TODO: later
    }
    
    public func isCamEnabled() -> Bool {
        // TODO: later
        return false
    }
    
    public func isMicEnabled() -> Bool {
        // TODO: later
        return false
    }
    
    public func sendMessage(message: RTVIClientIOS.RTVIMessageOutbound) throws {
        // TODO: later
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
}

