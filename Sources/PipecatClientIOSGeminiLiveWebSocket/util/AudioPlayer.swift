import AVFAudio

protocol AudioPlayerDelegate: AnyObject {
    func audioPlayerDidStartPlayback(_ audioPlayer: AudioPlayer)
    func audioPlayerDidFinishPlayback(_ audioPlayer: AudioPlayer)
    func audioPlayer(_ audioPlayer: AudioPlayer, didGetAudioLevel audioLevel: Float)
}

class AudioPlayer {
    
    // MARK: - Public
    
    public weak var delegate: AudioPlayerDelegate? = nil
    
    init() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        inputAudioFormat = AudioCommon.serverAudioFormat
        playerAudioFormat = AVAudioFormat(
            standardFormatWithSampleRate: inputAudioFormat.sampleRate,
            channels: inputAudioFormat.channelCount
        )!
        inputToPlayerAudioConverter = AVAudioConverter(from: inputAudioFormat, to: playerAudioFormat)!
    }
    
    func start() throws {
        if audioEngine.isRunning { return }
        // Setup the audio engine for playback
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        audioEngine.connect(
            playerNode,
            to: audioEngine.mainMixerNode,
            // doesn't seem to support pcm 16 here.
            // setting to nil doesn't work (defaults to 2 channels).
            // so, this?
            format: playerAudioFormat
        )
        
        // Install a tap to compute audio level
        AudioCommon.installAudioLevelTap(onNode: playerNode) { [weak self] audioLevel in
            guard let self else { return }
            delegate?.audioPlayer(self, didGetAudioLevel: audioLevel)
        }
        
        // Now start the engine
        try audioEngine.start()
        try playerNode.play()
    }
    
    func stop() {
        if !audioEngine.isRunning { return }
        AudioCommon.uninstallAudioLevelTap(onNode: playerNode)
        playerNode.stop()
        enqueuedBufferCount = 0
        audioEngine.stop()
    }
    
    // TODO: maybe someday be smarter so changing devices doesn't cut off current output
    func adaptToDeviceChange() throws {
        if !audioEngine.isRunning { return }
        stop()
        try start()
    }
    
    func clearEnqueuedBytes() {
        if !audioEngine.isRunning { return }
        playerNode.stop()
        enqueuedBufferCount = 0
        playerNode.play()
    }
    
    // Adapted from https://stackoverflow.com/questions/28048568/convert-avaudiopcmbuffer-to-nsdata-and-back
    func enqueueBytes(_ bytes: Data) {
        if !audioEngine.isRunning { return }
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
        try! inputToPlayerAudioConverter.convert(to: playerBuffer, from: inputBuffer)
        
        // Schedule it for playing
        playerNode.scheduleBuffer(playerBuffer, completionCallbackType: .dataPlayedBack) { [weak self] callbackType in
            if callbackType == .dataPlayedBack {
                self?.decrementEnqueuedBufferCount()
            }
        }
        incrementEnqueuedBufferCount()
    }
    
    // MARK: - Private
    
    private var audioEngine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private let inputAudioFormat: AVAudioFormat
    private let playerAudioFormat: AVAudioFormat
    private let inputToPlayerAudioConverter: AVAudioConverter
    private var enqueuedBufferCount = 0
    
    private func incrementEnqueuedBufferCount() {
        enqueuedBufferCount += 1
        if enqueuedBufferCount == 1 {
            delegate?.audioPlayerDidStartPlayback(self)
        }
    }
    
    private func decrementEnqueuedBufferCount() {
        guard enqueuedBufferCount > 0 else { return }
        enqueuedBufferCount -= 1
        if enqueuedBufferCount == 0 {
            delegate?.audioPlayerDidFinishPlayback(self)
        }
    }
}
