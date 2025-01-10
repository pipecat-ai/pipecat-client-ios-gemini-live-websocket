import AVFAudio

func installAudioLevelTap(onNode node: AVAudioNode, callback: @escaping (Float) -> ()) {
    let format = node.outputFormat(forBus: 0)
    let rate = format.sampleRate
    let bufferSize = rate / 10 // aim for computing audio level 10x/sec
    node.installTap(
        onBus: 0,
        bufferSize: AVAudioFrameCount(bufferSize),
        format: format) { buffer, _ in
            callback(calculateRMS(fromBuffer: buffer))
        }
}

func uninstallAudioLevelTap(onNode node: AVAudioNode) {
    node.removeTap(onBus: 0)
}

private func calculateRMS(fromBuffer buffer: AVAudioPCMBuffer) -> Float {
    let channelData = buffer.floatChannelData![0] // here we assume 1 channel
    let frameLength = Int(buffer.frameLength)
    var sum: Float = 0.0
    for frame in 0..<frameLength {
        sum += channelData[frame] * channelData[frame]
    }
    let meanSquare = sum / Float(frameLength)
    let rms = sqrt(meanSquare)
    return rms
}
