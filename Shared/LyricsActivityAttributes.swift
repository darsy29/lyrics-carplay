import ActivityKit
import Foundation

// This file must be added to BOTH targets (LyricsCarPlay and LyricsWidget).
// It's how the app and the widget extension agree on what data the
// Live Activity carries.
struct LyricsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentLine: String
        var nextLine: String
        var isPlaying: Bool
    }

    var trackName: String
    var artistName: String
}
