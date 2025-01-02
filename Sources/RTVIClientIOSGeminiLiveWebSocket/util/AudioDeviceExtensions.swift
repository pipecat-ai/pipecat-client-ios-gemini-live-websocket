import RTVIClientIOS

extension Device {
    func toRtvi() -> RTVIClientIOS.MediaDeviceInfo {
        return RTVIClientIOS.MediaDeviceInfo(id: MediaDeviceId(id: self.deviceID), name: self.label)
    }
}
