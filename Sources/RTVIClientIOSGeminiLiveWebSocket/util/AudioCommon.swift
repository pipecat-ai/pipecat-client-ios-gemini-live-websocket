import AVFAudio

// enum just for namespacing
enum AudioCommon {
    static var serverAudioFormat: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
    }()
    
    static let audioLevelReportingRate = 10
    
    static func installAudioLevelTap(onNode node: AVAudioNode, callback: @escaping (Float) -> ()) {
        let format = node.outputFormat(forBus: 0)
        let rate = format.sampleRate
        let bufferSize = rate / Double(audioLevelReportingRate)
        node.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(bufferSize),
            format: format) { buffer, _ in
                callback(calculateRMSAudioLevel(fromBuffer: buffer))
            }
    }

    static func uninstallAudioLevelTap(onNode node: AVAudioNode) {
        node.removeTap(onBus: 0)
    }

    static func calculateRMSAudioLevel(fromBuffer buffer: AVAudioPCMBuffer) -> Float {
        let channelData = buffer.floatChannelData![0] // here we assume 1 channel and float
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        for frame in 0..<frameLength {
            sum += channelData[frame] * channelData[frame]
        }
        let meanSquare = sum / Float(frameLength)
        let rms = sqrt(meanSquare)
        return rms
    }
}

