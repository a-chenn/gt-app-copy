import SwiftUI
import WidgetKit

struct GTFunEntry: TimelineEntry {
    let date: Date
}

/// Static text, so there is nothing to fetch and nothing to refresh.
struct GTFunProvider: TimelineProvider {
    func placeholder(in context: Context) -> GTFunEntry {
        GTFunEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (GTFunEntry) -> Void) {
        completion(GTFunEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GTFunEntry>) -> Void) {
        completion(Timeline(entries: [GTFunEntry(date: .now)], policy: .never))
    }
}

struct GTFunInlineView: View {
    var body: some View {
        Text("Go Jackets!")
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }
}

struct GTFunWidget: Widget {
    let kind = "GTFunWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GTFunProvider()) { _ in
            GTFunInlineView()
        }
        .configurationDisplayName("Go Jackets!")
        .description("A little school spirit on your Lock Screen.")
        .supportedFamilies([.accessoryInline])
    }
}

#Preview(as: .accessoryInline) {
    GTFunWidget()
} timeline: {
    GTFunEntry(date: .now)
}
