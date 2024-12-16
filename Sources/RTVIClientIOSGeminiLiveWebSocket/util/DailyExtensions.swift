import Foundation
import RTVIClientIOS
import Daily

extension Daily.AudioTrack {
    func toRtvi() -> MediaTrackId {
        return MediaTrackId(id: id)
    }
}

extension Daily.VideoTrack {
    func toRtvi() -> MediaTrackId {
        return MediaTrackId(id: id)
    }
}

extension Daily.ParticipantID {
    func toRtvi() -> RTVIClientIOS.ParticipantId {
        return RTVIClientIOS.ParticipantId(
            id: self.uuidString
        )
    }
}

extension Daily.Participant {
    func toRtvi() -> RTVIClientIOS.Participant {
        return RTVIClientIOS.Participant(
            id: self.id.toRtvi(),
            name: self.info.username,
            local: self.info.isLocal
        )
    }
}

extension Daily.Device {
    func toRtvi() -> RTVIClientIOS.MediaDeviceInfo {
        return RTVIClientIOS.MediaDeviceInfo(id: MediaDeviceId(id: self.deviceID), name: self.label)
    }
}
