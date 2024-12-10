import AVFoundation

private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!

class ModelAudioPlayer {
    
    init() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
    }
    
    func start() {
        audioEngine.attach(playerNode)
        
        audioEngine.connect(
            playerNode,
            to: audioEngine.mainMixerNode,
            format: audioFormat
        )
        
        do {
            // TODO: didn't think this should be necessary, but it is (otherwise will only make sound if phone is not in sient mode
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine.start()
            try playerNode.play()
            print("[pk] is audio engine running? \(audioEngine.isRunning)")
        } catch {
            print("[pk] AudioEngine didn't start: \(error.localizedDescription)")
        }

    }
    
    // Copilot version
//    func enqueueBytes(_ bytes: Data) {
//        bytes.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
//            guard let pointer = buffer.bindMemory(to: UInt8.self).baseAddress else {
//                return
//            }
//            let audioBuffer = AVAudioPCMBuffer(
//                pcmFormat: audioFormat,
//                frameCapacity: AVAudioFrameCount(bytes.count / Int(audioFormat.streamDescription.pointee.mBytesPerFrame))
//            )
//            audioBuffer?.frameLength = audioBuffer?.frameCapacity ?? 0
//            memcpy(audioBuffer?.floatChannelData?[0], pointer, bytes.count)
//            
//            playerNode.scheduleBuffer(audioBuffer!)
//            
//            print("[pk] scheduling buffer. frames: \(audioBuffer?.frameLength)")
//            playerNode.play()
//        }
//    }
    
    // Gemini version
//    func enqueueBytes(_ bytes: Data) {
//        let frameCount = UInt32(bytes.count / MemoryLayout<Float32>.size)
//        let pcmBuffer = AVAudioPCMBuffer(
//            pcmFormat: audioFormat,
//            frameCapacity: frameCount
//        )!
//        pcmBuffer.frameLength = frameCount
//        let audioBufferList = UnsafeMutableAudioBufferListPointer(pcmBuffer.mutableAudioBufferList)
//        let buffer = audioBufferList[0]
//        let dstBytes = buffer.mData!
//        bytes.copyBytes(to: dstBytes, count: bytes.count)
//        playerNode.scheduleBuffer(pcmBuffer)
//                    playerNode.play()
//    }
    
    // StackOverflow (this seems like the sanest)
    // https://stackoverflow.com/questions/28048568/convert-avaudiopcmbuffer-to-nsdata-and-back
    func enqueueBytes(_ bytes: Data) {
        let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: UInt32(bytes.count) / audioFormat.streamDescription.pointee.mBytesPerFrame
        )!
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        let channels = UnsafeBufferPointer(
            start: pcmBuffer.floatChannelData,
            count: Int(pcmBuffer.format.channelCount)
        )
        (bytes as NSData).getBytes(UnsafeMutableRawPointer(channels[0]) , length: bytes.count)
        print("[pk] scheduling buffer. frames: \(pcmBuffer.frameLength)")
        playerNode.scheduleBuffer(pcmBuffer)
    }
    
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
}
