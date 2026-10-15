import ActivityKit
import Foundation

@MainActor
final class LyricsSyncEngine: ObservableObject {
    @Published var currentTrack: SpotifyTrack?
    @Published var currentLine: String = "Waiting for playback..."
    @Published var statusMessage: String = ""

    private var pollTask: Task<Void, Never>?
    private var lyrics: [LyricLine] = []
    private var lyricsTrackID: String?
    private var activity: Activity<LyricsActivityAttributes>?

    func start() {
        stop()
        pollTask = Task {
            while !Task.isCancelled {
                await pollOnce()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func pollOnce() async {
        do {
            guard let track = try await SpotifyClient.fetchCurrentlyPlaying() else {
                statusMessage = "Nothing playing on Spotify"
                await endActivity()
                return
            }
            currentTrack = track

            if track.id != lyricsTrackID {
                lyricsTrackID = track.id
                lyrics = await LyricsClient.fetchLyrics(
                    track: track.name,
                    artist: track.artist,
                    album: track.album,
                    durationSec: track.durationMs / 1000
                ) ?? []
                statusMessage = lyrics.isEmpty ? "No lyrics found for this track" : "Lyrics loaded"
            }

            let index = currentLyricIndex(for: track)
            let line = index.map { lyrics[$0].text } ?? (lyrics.first.map { "♪ \($0.text)" } ?? "No lyrics found")
            let next = index.flatMap { $0 + 1 < lyrics.count ? lyrics[$0 + 1].text : nil } ?? ""

            currentLine = line
            await updateActivity(track: track, line: line, nextLine: next)
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    // Returns the index of the current lyric line rather than the text itself,
    // so repeated lines (choruses, "la la la") don't all resolve to the same
    // spot when looking up what comes next.
    private func currentLyricIndex(for track: SpotifyTrack) -> Int? {
        guard !lyrics.isEmpty else { return nil }

        // Estimate real-time position between polls so lines don't feel stuck.
        let elapsed = track.isPlaying
            ? Date().timeIntervalSince(track.fetchedAt) + Double(track.progressMs) / 1000
            : Double(track.progressMs) / 1000

        return lyrics.lastIndex { $0.time <= elapsed }
    }

    private func updateActivity(track: SpotifyTrack, line: String, nextLine: String) async {
        let state = LyricsActivityAttributes.ContentState(
            currentLine: line,
            nextLine: nextLine,
            isPlaying: track.isPlaying
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(20))

        if let activity {
            await activity.update(content)
        } else {
            let attributes = LyricsActivityAttributes(trackName: track.name, artistName: track.artist)
            activity = try? Activity.request(attributes: attributes, content: content)
        }
    }

    private func endActivity() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
