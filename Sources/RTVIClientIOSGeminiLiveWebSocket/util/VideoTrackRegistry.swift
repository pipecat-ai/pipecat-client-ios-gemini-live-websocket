import Daily
import RTVIClientIOS

final class VideoTrackRegistry {

    // Dictionary to store the original track and associated MediaTrackId
    private static var trackMap: [MediaTrackId: VideoTrack] = [:]

    // Method to store the original track and MediaTrackId
    static func registerTrack(originalTrack: VideoTrack, mediaTrackId: MediaTrackId) {
        trackMap[mediaTrackId] = originalTrack
    }

    // Retrieves the original track
    static func getTrack(mediaTrackId: MediaTrackId) -> VideoTrack? {
        return trackMap[mediaTrackId]
    }

    // Method to clear all tracks from the registry
    static func clearRegistry() {
        trackMap.removeAll()
    }

}
