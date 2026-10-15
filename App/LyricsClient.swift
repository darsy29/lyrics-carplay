import Foundation

struct LyricLine {
    let time: TimeInterval
    let text: String
}

enum LyricsClient {
    // LRCLIB is free, needs no API key, and has no rate limit.
    static func fetchLyrics(track: String, artist: String, album: String, durationSec: Int) async -> [LyricLine]? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album),
            URLQueryItem(name: "duration", value: String(durationSec))
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        // LRCLIB asks (not requires) that you identify your app.
        request.setValue("LyricsCarPlay/1.0 (https://github.com/darsy29/lyrics-carplay)", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }

        struct Response: Decodable {
            let syncedLyrics: String?
        }
        guard let result = try? JSONDecoder().decode(Response.self, from: data),
              let synced = result.syncedLyrics, !synced.isEmpty else {
            return nil // No synced lyrics for this track — the sync engine shows a friendly fallback.
        }

        let lines = parseLRC(synced)
        return lines.isEmpty ? nil : lines
    }

    private static func parseLRC(_ raw: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        for rawLine in raw.split(separator: "\n") {
            guard let close = rawLine.firstIndex(of: "]") else { continue }
            let tag = rawLine[rawLine.index(after: rawLine.startIndex)..<close]
            let text = String(rawLine[rawLine.index(after: close)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let parts = tag.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]) else { continue } // skips metadata tags like [ar:], [ti:]

            lines.append(LyricLine(time: minutes * 60 + seconds, text: text))
        }

        return lines.sorted { $0.time < $1.time }
    }
}
