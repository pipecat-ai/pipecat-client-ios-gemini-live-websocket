import AVFoundation

// enum just for namespacing
enum AudioConstants {
    static var format: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
    }()
}

