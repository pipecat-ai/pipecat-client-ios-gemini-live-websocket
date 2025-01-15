import AVFAudio
import Foundation

/// Enumerated value specifying a device's kind.
public enum DeviceKind: RawRepresentable, CaseIterable, Equatable, Hashable {
    case videoInput
    case audio(PortKind)

    public typealias RawValue = String

    public var rawValue: RawValue {
        switch self {
        case .videoInput:
            return "videoinput"
        case .audio(.input):
            return "audioinput"
        case .audio(.output):
            return "audiooutput"
        }
    }

    static public var allCases: [DeviceKind] {
        [.videoInput, .audio(.input), .audio(.output)]
    }

    public init?(rawValue: RawValue) {
        switch rawValue {
        case "videoinput":
            self = .videoInput
        case "audioinput":
            self = .audio(.input)
        case "audiooutput":
            self = .audio(.output)
        case _:
            return nil
        }
    }
}

public enum PortKind: CaseIterable, Equatable, Hashable {
    case input
    case output
}

public enum AudioDeviceType: String, RawRepresentable {
    case bluetooth
    case speakerphone
    case wired
    case earpiece

    public var deviceID: String {
        self.rawValue
    }

    public init?(deviceID: String) {
        self.init(rawValue: deviceID)
    }

    @_spi(Testing)
    public init?(sessionPort: AVAudioSession.Port) {
        switch sessionPort {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            self = .bluetooth
        case .builtInReceiver:
            self = .earpiece
        case .headphones, .headsetMic:
            self = .wired
        case .builtInSpeaker, .builtInMic:
            self = .speakerphone
        case _:
            return nil
        }
    }
}

extension DeviceKind: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        guard let value = DeviceKind(rawValue: stringValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized device kind '\(stringValue)'"
                )
            )
        }
        self = value
    }
}

/// Information that describes a single media input or output device.
public struct Device: Equatable {
    /// Identifier for the represented device that is persistent across application launches.
    public let deviceID: String
    public let groupID: String

    /// Enumerated value specifying the device kind.
    public let kind: DeviceKind

    /// A label describing this device (e.g. "External USB Webcam").
    public let label: String

    @_spi(Testing)
    public init(
        deviceID: String,
        groupID: String,
        kind: DeviceKind,
        label: String
    ) {
        self.deviceID = deviceID
        self.groupID = groupID
        self.kind = kind
        self.label = label
    }
}

extension Device: Codable {
    enum CodingKeys: String, CodingKey {
        case deviceID = "deviceId"
        case groupID = "groupId"
        case kind
        case label
    }
}
