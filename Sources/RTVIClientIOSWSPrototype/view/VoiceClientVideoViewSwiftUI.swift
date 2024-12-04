import SwiftUI
import Daily
import RTVIClientIOS

/// A wrapper for `VoiceClientVideoView` that exposes the video size via a `@Binding`.
public struct VoiceClientVideoViewSwiftUI: UIViewRepresentable {
    
    /// The current size of the video being rendered by this view.
    @Binding private(set) var videoSize: CGSize

    private let voiceClientTrack: MediaTrackId?
    private let videoScaleMode: VoiceClientVideoView.VideoScaleMode

    public init(
        voiceClientTrack: MediaTrackId? = nil,
        videoScaleMode: VoiceClientVideoView.VideoScaleMode = .fill,
        videoSize: Binding<CGSize> = .constant(.zero)
    ) {
        self.voiceClientTrack = voiceClientTrack
        self.videoScaleMode = videoScaleMode
        self._videoSize = videoSize
    }

    public func makeUIView(context: Context) -> VoiceClientVideoView {
        let videoView = VoiceClientVideoView()
        videoView.delegate = context.coordinator
        return videoView
    }

    public func updateUIView(_ videoView: VoiceClientVideoView, context: Context) {
        context.coordinator.dailyVideoView = self

        if videoView.voiceClientTrack != voiceClientTrack {
            videoView.voiceClientTrack = voiceClientTrack
        }

        if videoView.videoScaleMode != videoScaleMode {
            videoView.videoScaleMode = videoScaleMode
        }
    }
}

extension VoiceClientVideoViewSwiftUI {
    public final class Coordinator: VideoViewDelegate {
        fileprivate var dailyVideoView: VoiceClientVideoViewSwiftUI

        init(_ dailyVideoView: VoiceClientVideoViewSwiftUI) {
            self.dailyVideoView = dailyVideoView
        }

        public func videoView(_ videoView: Daily.VideoView, didChangeVideoSize size: CGSize) {
            // Update the `videoSize` binding with the current `size` value.
            DispatchQueue.main.async {
                self.dailyVideoView.videoSize = size
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

#Preview {
    VoiceClientVideoViewSwiftUI()
}
