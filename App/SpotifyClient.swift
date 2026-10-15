import Foundation

struct SpotifyTrack: Equatable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let durationMs: Int
    let progressMs: Int
    let isPlaying: Bool
    let fetchedAt: Date
}

enum SpotifyClient {
    static func fetchCurrentlyPlaying() async throws -> SpotifyTrack? {
        let token = try await SpotifyAuth.shared.validAccessToken()

        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        // 204 = nothing currently playing
        if let http = response as? HTTPURLResponse, http.statusCode == 204 {
            return nil
        }

        struct Item: Decodable {
            struct Album: Decodable { let name: String }
            struct Artist: Decodable { let name: String }
            let id: String
            let name: String
            let duration_ms: Int
            let album: Album
            let artists: [Artist]
        }
        struct PlaybackState: Decodable {
            let item: Item?
            let progress_ms: Int?
            let is_playing: Bool
        }

        let state = try JSONDecoder().decode(PlaybackState.self, from: data)
        guard let item = state.item else { return nil }

        return SpotifyTrack(
            id: item.id,
            name: item.name,
            artist: item.artists.first?.name ?? "",
            album: item.album.name,
            durationMs: item.duration_ms,
            progressMs: state.progress_ms ?? 0,
            isPlaying: state.is_playing,
            fetchedAt: Date()
        )
    }
}
