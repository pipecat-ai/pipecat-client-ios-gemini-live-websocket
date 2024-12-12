import AVFAudio

class AudioRecorder {

    // MARK: - Public
    
    func start() throws {
        // If setup already happened, just start the engine
        if didSetup {
            try audioEngine.start()
            return
        }
        
        try AudioCommon.prepareAudioSession()
        
        // Setup the audio engine for recording
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let formatConverter = AVAudioConverter(
            from: inputFormat,
            to: AudioCommon.format
        )!
        audioEngine.inputNode.installTap(
            onBus: 0,
            // 1 second buffer. TODO: is this a reasonable value?
            bufferSize: UInt32(AudioCommon.format.sampleRate),
            format: inputFormat
        ) { inputBuffer, time in
            // Convert captured buffer to target format
            let targetBuffer = Self.convertToTargetFormat(
                inputBuffer: inputBuffer,
                inputFormat: inputFormat,
                targetFormat: AudioCommon.format,
                formatConverter: formatConverter)
            
            // Convert buffer to data
            let channels = UnsafeBufferPointer(
                start: targetBuffer.int16ChannelData,
                count: Int(targetBuffer.format.channelCount)
            )
            let data = NSData(
                bytes: channels[0],
                length: Int(targetBuffer.frameCapacity * targetBuffer.format.streamDescription.pointee.mBytesPerFrame)
            )
            
            self.getAudioContinuation?.yield(data as Data)
        }
        
        // Now start the engine
        try audioEngine.start()
        
        didSetup = true
    }
    
    func stop() {
        
    }
    
    func getAudio() -> AsyncStream<Data> {
        return AsyncStream { continuation in
            getAudioContinuation = continuation
        }
    }
    
    // MARK: - Private
    
    private var didSetup = false
    private let audioEngine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "com.pipecat.GeminiLiveWebSocketTransport.AudioRecorder")
    private var getAudioContinuation: AsyncStream<Data>.Continuation?
    
    private static func convertToTargetFormat(
        inputBuffer: AVAudioPCMBuffer,
        inputFormat: AVAudioFormat,
        targetFormat: AVAudioFormat,
        formatConverter: AVAudioConverter) -> AVAudioPCMBuffer
    {
        let targetBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(targetFormat.sampleRate) * 2 // to be safe
        )!
        var error: NSError?
        var inputIndex: AVAudioFramePosition = 0
        formatConverter.convert(
            to: targetBuffer,
            error: &error) { numberOfFrames, inputStatus in
                if (inputIndex >= inputBuffer.frameLength) {
                    inputStatus.pointee = .noDataNow
                    return AVAudioBuffer()
                }
                inputStatus.pointee = .haveData
                let startFrame = inputIndex
                let endFrame = min(
                    inputIndex + Int64(numberOfFrames),
                    AVAudioFramePosition(inputBuffer.frameLength)
                )
                inputIndex = endFrame
                let segment = segment(
                    of: inputBuffer,
                    from: startFrame,
                    to: endFrame
                )
                return segment
            }
        if let error {
            print("[pk] Error converting raw mic audio data into target format: \(error)")
        }
        return targetBuffer
    }
    
    // From https://stackoverflow.com/questions/53162241/play-segment-of-avaudiopcmbuffer
    private static func segment(
        of buffer: AVAudioPCMBuffer,
        from startFrame: AVAudioFramePosition,
        to endFrame: AVAudioFramePosition // 1 past last frame index
    ) -> AVAudioPCMBuffer? {
        let framesToCopy = AVAudioFrameCount(endFrame - startFrame)
        guard let segment = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: framesToCopy
        ) else { return nil }

        let sampleSize = buffer.format.streamDescription.pointee.mBytesPerFrame

        let srcPtr = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let dstPtr = UnsafeMutableAudioBufferListPointer(segment.mutableAudioBufferList)
        for (src, dst) in zip(srcPtr, dstPtr) {
            memcpy(dst.mData, src.mData?.advanced(by: Int(startFrame) * Int(sampleSize)), Int(framesToCopy) * Int(sampleSize))
        }

        segment.frameLength = framesToCopy
        return segment
    }
}
