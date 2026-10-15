import ActivityKit
import SwiftUI
import WidgetKit

struct LyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.currentLine)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
            } compactLeading: {
                Image(systemName: "music.note")
            } compactTrailing: {
                Text(context.attributes.trackName)
                    .font(.caption2)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "music.note")
            }
        }
    }
}

// This is also what shows on the CarPlay Dashboard and lock screen.
private struct LockScreenView: View {
    let context: ActivityViewContext<LyricsActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(context.attributes.trackName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(context.state.currentLine)
                .font(.headline)
                .lineLimit(2)
            if !context.state.nextLine.isEmpty {
                Text(context.state.nextLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
    }
}
