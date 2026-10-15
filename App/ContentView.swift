import SwiftUI

struct ContentView: View {
    @StateObject private var auth = SpotifyAuth.shared
    @StateObject private var engine = LyricsSyncEngine()

    var body: some View {
        VStack(spacing: 20) {
            Text("Lyrics for CarPlay")
                .font(.title2.bold())

            if auth.isAuthorized {
                VStack(spacing: 8) {
                    Text(engine.currentTrack?.name ?? "No track yet")
                        .font(.headline)
                    Text(engine.currentTrack?.artist ?? "")
                        .foregroundStyle(.secondary)
                    Text(engine.currentLine)
                        .padding()
                        .multilineTextAlignment(.center)
                    Text(engine.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onAppear { engine.start() }
                .onDisappear { engine.stop() }
            } else {
                Button("Connect Spotify") {
                    auth.login()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
