import Foundation

/// Helper class to identify when the participant is speaking based on the audio level.
class AudioLevelProcessor {
    
    // callback
    private let onIsSpeaking: (Bool) -> Void
    
    private let threshold: Float
    private let silenceDelayMs: TimeInterval
    private var speaking = false
    private var silencePending: DispatchWorkItem?

    init(threshold: Float = 0.05, silenceDelayMs: TimeInterval = 750, onIsSpeaking: @escaping (Bool) -> Void) {
        self.onIsSpeaking = onIsSpeaking
        self.threshold = threshold
        self.silenceDelayMs = silenceDelayMs
    }

    func onLevelChanged(level: Float) {
        if level > threshold {
            if let pending = self.silencePending {
                pending.cancel()
                self.silencePending = nil
            }
            if !self.speaking {
                self.speaking = true
                self.onIsSpeaking(true)
            }
        } else if speaking && silencePending == nil {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.speaking = false
                self.silencePending = nil
                self.onIsSpeaking(false)
            }
            self.silencePending = workItem
            let delayInSeconds = self.silenceDelayMs / 1000
            DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds, execute: workItem)
        }
    }
}
