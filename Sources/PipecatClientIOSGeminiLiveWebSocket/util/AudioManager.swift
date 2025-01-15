import AVFAudio

protocol AudioManagerDelegate: AnyObject {
    func audioManagerDidChangeDevices(
        _ audioManager: AudioManager
    )
}

final class AudioManager {
    internal weak var delegate: AudioManagerDelegate? = nil

    /// user's explicitly preferred device.
    /// nil means "current system default".
    internal var preferredAudioDevice: AudioDeviceType? = nil {
        didSet {
            if self.preferredAudioDevice != oldValue {
                self.configureAudioSession()
            }
        }
    }

    /// the actual audio device in use.
    internal var audioDevice: AudioDeviceType {
        let defaultDevice: AudioDeviceType = Self.defaultDevice

        guard let firstOutput = self.audioSession.currentRoute.outputs.first else {
            return defaultDevice
        }

        guard let audioDevice = AudioDeviceType(sessionPort: firstOutput.portType) else {
            return defaultDevice
        }

        return audioDevice
    }
    
    /// the user's preferred device, if it's available, or nil—signifying "current system default"—otherwise.
    /// this is the basis of the selectedMic() exposed to the user, matching the Daily transport's behavior.
    internal var preferredAudioDeviceIfAvailable: AudioDeviceType? {
        self.preferredAudioDeviceIsAvailable(preferredAudioDevice) ? self.preferredAudioDevice : nil
    }

    private var isManaging: Bool = false
    private let notificationCenter: NotificationCenter

    // The AVAudioSession class is only available as a singleton:
    // https://developer.apple.com/documentation/avfaudio/avaudiosession/1648777-init
    private let audioSession: AVAudioSession = .sharedInstance()

    private var overriddenMode: AVAudioSession.Mode
    private var overriddenCategory: AVAudioSession.Category
    private var overriddenCategoryOptions: AVAudioSession.CategoryOptions

    private static var defaultDevice: AudioDeviceType {
        .speakerphone
    }

    internal convenience init() {
        self.init(
            notificationCenter: .default
        )
    }

    internal init(
        notificationCenter: NotificationCenter
    ) {
        // We have an issue with iOS 17 simulator, more details in this thread:
        // https://forums.developer.apple.com/forums/thread/738346
        // If the current iOS version is greater than 17, we are applying a workaround to fix it
        #if targetEnvironment(simulator)
            if UIDevice.current.systemVersion.compare("17", options: .numeric) == .orderedDescending {
                Logger.shared.info("Applying workaround for iOS 17 simulator")
                do {
                    try self.audioSession.setActive(true)
                } catch let error {
                    Logger.shared.error("Error when applying workaroung for iOS 17 simulator: \(error)")
                }
            }
        #endif

        self.notificationCenter = notificationCenter

        self.overriddenMode = audioSession.mode
        self.overriddenCategory = audioSession.category
        self.overriddenCategoryOptions = audioSession.categoryOptions

        self.addNotificationObservers()
    }

    // MARK: - API

    func startManagingIfNecessary() {
        guard !self.isManaging else {
            return
        }
        self.startManaging()
    }

    func startManaging() {
        assert(self.isManaging == false)

        self.isManaging = true

        // Save current session configuration, so we can revert back to it
        // once we stop managing the audio:
        self.overriddenMode = self.audioSession.mode
        self.overriddenCategory = self.audioSession.category
        self.overriddenCategoryOptions = self.audioSession.categoryOptions

        self.configureAudioSession()
    }

    func stopManaging() {
        assert(self.isManaging == true)

        self.isManaging = false

        self.resetAudioSession()
    }
    
    // Adapted from WebrtcDevicesManager in Daily
    var availableDevices: [Device] {
        let audioSession = self.audioSession
        let availableInputs = audioSession.availableInputs ?? []
        let availableOutputs = audioSession.currentRoute.outputs

        var deviceTypes = availableInputs.compactMap { input in
            AudioDeviceType(sessionPort: input.portType)
        }
        // It always returns or earpiece or speakerphone on available inputs, depending on th category that
        // we are using. So we need to add the one that is missing.
        if deviceTypes.contains(AudioDeviceType.speakerphone) {
            deviceTypes.append(AudioDeviceType.earpiece)
        } else {
            deviceTypes.append(AudioDeviceType.speakerphone)
        }

        // When we are using bluetooth as the default route,
        // iOS does not list the bluetooth device on the list of availableInputs
        let outputDevice = availableOutputs.first.flatMap { AudioDeviceType(sessionPort: $0.portType) }
        if let outputDevice {
            if !deviceTypes.contains(outputDevice) {
                deviceTypes.append(outputDevice)
            }
        }

        // bluetooth and earpiece should only be available in case we don't have a wired headset plugged
        // otherwise we can never change the route to bluetooth or earpiece, iOS does not respect that
        if deviceTypes.contains(AudioDeviceType.wired) {
            deviceTypes = deviceTypes.filter { device in
                device != AudioDeviceType.bluetooth && device != AudioDeviceType.earpiece
            }
        }

        // NOTE: we use .input for the kind of all of these, since we only care about reporting mics
        return deviceTypes.map { deviceType in
            switch deviceType {
            case .bluetooth:
                return .init(
                    deviceID: deviceType.deviceID,
                    groupID: "",
                    kind: .audio(.input),
                    label: "Bluetooth Speaker & Mic"
                )
            case .speakerphone:
                return .init(
                    deviceID: deviceType.deviceID,
                    groupID: "",
                    kind: .audio(.input),
                    label: "Built-in Speaker & Mic"
                )
            case .wired:
                return .init(
                    deviceID: deviceType.deviceID,
                    groupID: "",
                    kind: .audio(.input),
                    label: "Wired Speaker & Mic"
                )
            case .earpiece:
                return .init(
                    deviceID: deviceType.deviceID,
                    groupID: "",
                    kind: .audio(.input),
                    label: "Built-in Earpiece & Mic"
                )
            }
        }
    }

    // MARK: - Notifications

    private func addNotificationObservers() {
        self.notificationCenter.addObserver(
            self,
            selector: #selector(routeDidChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: self.audioSession
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(mediaServicesWereReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: self.audioSession
        )
    }

    @objc private func routeDidChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            return
        }

        var audioManagerDidChangeDevices = false

        switch reason {
        case .newDeviceAvailable:
            audioManagerDidChangeDevices = true
        case .oldDeviceUnavailable:
            audioManagerDidChangeDevices = true
        case .override:
            // Return in order to avoid an infinite config loop.
            return
        case .unknown, .categoryChange, .wakeFromSleep, .noSuitableRouteForCategory,
            .routeConfigurationChange:
            // Return for now, to avoid undesired infinite loops.
            return
        @unknown default:
            Logger.shared.warn("Ignoring unknown audio route change reason: \(reason)")
            return
        }

        if audioManagerDidChangeDevices {
            self.configureAudioSession()
            // We're firing this delegate *after* we're configuring the audio session so that in the delegate we can already assume a new device is ready for use
            if isManaging {
                self.delegate?.audioManagerDidChangeDevices(self)
            }
        }
    }

    @objc private func mediaServicesWereReset(_ notification: Notification) {
        self.configureAudioSession()
    }

    // MARK: - Configuration

    private func resetAudioSession() {
        do {
            // Restoring the session to the previous values
            try self.audioSession.setCategory(
                self.overriddenCategory,
                mode: self.overriddenMode,
                options: self.overriddenCategoryOptions
            )
        } catch {
            Logger.shared.error("Error configuring audio session")
        }
    }

    private func configureAudioSession() {
        // Do nothing if we still not in a call
        if !self.isManaging {
            return
        }

        do {
            if self.preferredAudioDevice != self.audioDevice {
                try self.apply(preferredAudioDevice: preferredAudioDevice)
            }
        } catch {
            Logger.shared.error("Error configuring audio session")
        }
    }

    private func preferredAudioDeviceIsAvailable(_ preferredAudioDevice: AudioDeviceType?) -> Bool {
        var allowedPortTypes: [AVAudioSession.Port]

        switch preferredAudioDevice {
        case .wired?:
            allowedPortTypes = [.headphones, .headsetMic]
        case .bluetooth?:
            allowedPortTypes = [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
        case .earpiece?, .speakerphone?:
            return true
        case nil:
            return false
        }

        var hasPreferredDevice = false
        if let availableInputs = self.audioSession.availableInputs {
            hasPreferredDevice = availableInputs.contains { allowedPortTypes.contains($0.portType) }
        }
        return hasPreferredDevice || self.audioSession.currentRoute.outputs.contains { allowedPortTypes.contains($0.portType) }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    internal func apply(preferredAudioDevice: AudioDeviceType?) throws {
        let session = self.audioSession

        var sessionMode: AVAudioSession.Mode = .voiceChat
        let sessionCategory: AVAudioSession.Category = .playAndRecord

        // Mixing audio with other apps allows this app to stay alive in the background during
        // a call (assuming it has the voip background mode set).
        // After iOS 16, we must also always keep the bluetooth option here, otherwise
        // we are not able to see the bluetooth devices on the list
        var sessionCategoryOptions: AVAudioSession.CategoryOptions = [
            .allowBluetooth,
            .mixWithOthers,
        ]

        let preferredDeviceToUse = preferredAudioDeviceIfAvailable

        switch preferredDeviceToUse {
        case .speakerphone?:
            sessionCategoryOptions.insert(.defaultToSpeaker)
            sessionMode = AVAudioSession.Mode.videoChat
        case .earpiece?, .bluetooth?, .wired?:
            break
        case nil:
            sessionMode = AVAudioSession.Mode.videoChat
        }

        do {
            try session.setCategory(
                sessionCategory,
                mode: sessionMode,
                options: sessionCategoryOptions
            )
        } catch {
            Logger.shared.error("Error configuring audio session")
        }

        let preferredInput: AVAudioSessionPortDescription?
        let overriddenOutputAudioPort: AVAudioSession.PortOverride
        switch preferredDeviceToUse {
        case .bluetooth?:
            preferredInput = nil
            overriddenOutputAudioPort = .none
        case .speakerphone?:
            preferredInput = nil
            // Force to speaker. We only need to do that the cases a wired
            // headset is connected, but we still want to force to speaker
            overriddenOutputAudioPort = .speaker
        case .wired?:
            preferredInput = nil
            overriddenOutputAudioPort = .none
        case .earpiece?:
            // We just try to force the preferred input to earpiece
            // if we don't already have a wired headset plugged
            // Because otherwise it will always use the wired headset.
            // It is not possible to choose the earpiece in this case.
            preferredInput = session.availableInputs?
                .first {
                    $0.portType == .builtInMic
                }
            overriddenOutputAudioPort = .none
        case nil:
            preferredInput = nil
            overriddenOutputAudioPort = .none
        }

        do {
            try session.overrideOutputAudioPort(overriddenOutputAudioPort)
        } catch let error {
            Logger.shared.error("Error overriding output audio port: \(error)")
        }
        if preferredInput != nil {
            do {
                try session.setPreferredInput(preferredInput)
            } catch let error {
                Logger.shared.error("Error configuring preferred input audio port: \(error)")
            }
        }
    }
}
