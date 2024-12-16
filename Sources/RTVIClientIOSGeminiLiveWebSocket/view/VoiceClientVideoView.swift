import Daily
import RTVIClientIOS

/// Overrides the Daily [VideoView] to allow [MediaTrackId] tracks from the VoiceClient to be rendered.
public final class VoiceClientVideoView: VideoView {
    
    /// Displays the specified [MediaTrackId] in this view.
    public var voiceClientTrack: MediaTrackId? {
        get {
            if let track = track {
                return MediaTrackId(id: track.id)
            }
            return nil
        }
        set {
            if let value = newValue {
                self.track = VideoTrackRegistry.getTrack(mediaTrackId: value)
            } else {
                track = nil
            }
        }
    }
    
}
