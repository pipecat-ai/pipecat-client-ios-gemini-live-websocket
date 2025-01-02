import AVFAudio

class AudioRecorder {

    // MARK: - Public
    
    var isRecording: Bool {
        audioEngine.isRunning
    }
    
    func resume() throws {
        // If setup already happened, just start the engine
        if didSetup {
            try audioEngine.start()
            return
        }
        
        // Setup the audio engine for recording
        try audioEngine.inputNode.setVoiceProcessingEnabled(true) // important for ignoring output from the phone itself
        let inputNode = audioEngine.inputNode
        // Hmm, we really *should* be using inputNode.outputFormat, but for some reason after disconnecting then the voice cclient outputFormat reports 0hz sample rate, even though it *does* work (installing the tap works).
        // Some post suggests using the input format instead of the output one? https://stackoverflow.com/a/47902479
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let formatConverter = AVAudioConverter(
            from: inputFormat,
            to: AudioCommon.format
        )!
        audioEngine.inputNode.installTap(
            onBus: 0,
            // 1 second buffer
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
                // (Hack: we happen to know that target format is Int16)
                start: targetBuffer.int16ChannelData,
                count: Int(targetBuffer.format.channelCount)
            )
            let data = NSData(
                bytes: channels[0],
                length: Int(targetBuffer.frameLength * targetBuffer.format.streamDescription.pointee.mBytesPerFrame)
            )
            
            self.streamAudioContinuation?.yield(data as Data)
        }
        
        // Now start the engine
        try audioEngine.start()
        
        didSetup = true
    }
    
    func pause() {
        audioEngine.pause()
    }
    
    func stop() {
        stop(andEndStream: true)
    }
    
    func streamAudio() -> AsyncStream<Data> {
        return AsyncStream { continuation in
            streamAudioContinuation = continuation
        }
    }
    
    func adaptToDeviceChange() throws {
        if !didSetup { return }
        stop(andEndStream: false)
        audioEngine = AVAudioEngine()
        didSetup = false
        try resume()
    }
    
    // MARK: - Private
    
    private var didSetup = false
    private var audioEngine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "com.pipecat.GeminiLiveWebSocketTransport.AudioRecorder")
    private var streamAudioContinuation: AsyncStream<Data>.Continuation?
    
    func stop(andEndStream endStream: Bool) {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        if endStream {
            streamAudioContinuation?.finish()
        }
    }
    
    private static func convertToTargetFormat(
        inputBuffer: AVAudioPCMBuffer,
        inputFormat: AVAudioFormat,
        targetFormat: AVAudioFormat,
        formatConverter: AVAudioConverter) -> AVAudioPCMBuffer
    {
        let targetBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: inputBuffer.frameLength
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
        // UGH this feels like a total hack. But somehow the format converter is assigning a nonsense frameLength to the targetBuffer?
        targetBuffer.frameLength = inputBuffer.frameLength
        if let error {
            Logger.shared.warn("Error converting raw mic audio data into target format: \(error)")
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
