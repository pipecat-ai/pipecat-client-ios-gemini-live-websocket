import AVFoundation

// enum just for namespacing
enum AudioCommon {
    static var format: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
    }()
    
    static func prepareAudioSession() throws {
        // TODO: didn't think this should be necessary, but it is (otherwise will only make sound if phone is not in sient mode
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord) // TODO: move to common place
        try AVAudioSession.sharedInstance().setActive(true)
    }
}

