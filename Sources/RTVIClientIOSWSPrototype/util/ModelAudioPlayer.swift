import AVFoundation

class ModelAudioPlayer {
    
    init() {
        // TODO: error handling when creating all these?
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        inputAudioFormat = AudioCommon.format
        playerAudioFormat = AVAudioFormat(
            standardFormatWithSampleRate: inputAudioFormat.sampleRate,
            channels: inputAudioFormat.channelCount
        )!
        inputToPlayerAudioConverter = AVAudioConverter(from: inputAudioFormat, to: playerAudioFormat)!
    }
    
    func start() throws {
        try AudioCommon.prepareAudioSession()
        
        audioEngine.attach(playerNode)
        audioEngine.connect(
            playerNode,
            to: audioEngine.mainMixerNode,
            // doesn't seem to support pcm 16 here.
            // setting to nil doesn't work (defaults to 2 channels).
            // so, this?
            format: playerAudioFormat
        )
        try audioEngine.start()
        try playerNode.play()
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
//    func enqueueBytes(_ bytes: Data) {
//        let pcmBuffer = AVAudioPCMBuffer(
//            pcmFormat: audioFormat,
//            frameCapacity: UInt32(bytes.count) / audioFormat.streamDescription.pointee.mBytesPerFrame
//        )!
//        pcmBuffer.frameLength = pcmBuffer.frameCapacity
//        let channels = UnsafeBufferPointer(
//            start: pcmBuffer.floatChannelData,
//            count: Int(pcmBuffer.format.channelCount)
//        )
//        (bytes as NSData).getBytes(UnsafeMutableRawPointer(channels[0]) , length: bytes.count)
//        print("[pk] scheduling buffer. frames: \(pcmBuffer.frameLength)")
//        
//        // debugging
//        var arr = Array<Int16>(repeating: 0, count: bytes.count/MemoryLayout<Int16>.stride)
//        _ = arr.withUnsafeMutableBytes { bytes.copyBytes(to: $0) }
//        print("frames as int16s: \(arr)") // [32, 4, 4294967295]
//        // end debugging
//        
//        playerNode.scheduleBuffer(pcmBuffer)
//    }
    
    // StackOverflow (this seems like the sanest)
    // But for int16 format instead of float32
    // https://stackoverflow.com/questions/28048568/convert-avaudiopcmbuffer-to-nsdata-and-back
    func enqueueBytes(_ bytes: Data) {
        // Prepare input buffer
        let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: inputAudioFormat,
            frameCapacity: UInt32(bytes.count) / inputAudioFormat.streamDescription.pointee.mBytesPerFrame
        )!
        inputBuffer.frameLength = inputBuffer.frameCapacity
        let channels = UnsafeBufferPointer(
            start: inputBuffer.int16ChannelData,
            count: Int(inputBuffer.format.channelCount)
        )
        (bytes as NSData).getBytes(UnsafeMutableRawPointer(channels[0]) , length: bytes.count)
        
        // Convert to player-ready buffer
        let playerBuffer = AVAudioPCMBuffer(
            pcmFormat: playerAudioFormat,
            frameCapacity: inputBuffer.frameCapacity
        )!
        // TODO: error handling
        try! inputToPlayerAudioConverter.convert(to: playerBuffer, from: inputBuffer)
        
        // Schedule it for playing
        print("[pk] scheduling buffer. frames: \(playerBuffer.frameLength)")
        playerNode.scheduleBuffer(playerBuffer)
    }
    
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let inputAudioFormat: AVAudioFormat
    private let playerAudioFormat: AVAudioFormat
    private let inputToPlayerAudioConverter: AVAudioConverter
}
