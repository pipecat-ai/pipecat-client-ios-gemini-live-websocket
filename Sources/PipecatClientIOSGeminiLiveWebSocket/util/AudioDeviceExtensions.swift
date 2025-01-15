import PipecatClientIOS

extension Device {
    func toRtvi() -> PipecatClientIOS.MediaDeviceInfo {
        return PipecatClientIOS.MediaDeviceInfo(id: MediaDeviceId(id: self.deviceID), name: self.label)
    }
}
