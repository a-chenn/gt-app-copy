import SwiftUI
import WidgetKit

/// Shared Lock Screen rectangular layout from the Figma spec:
/// [icon] title / subtitle / dim detail, with an optional leading bar (Events).
struct AccessoryThreeLines: View {
    var icon: String? = nil
    var showsBar = false
    let title: String
    let subtitle: String
    var detail: String? = nil
    var detailIcon: String? = nil

    private let titleFont = Font.callout.weight(.bold)
    private let bodyFont = Font.callout.weight(.medium)

    var body: some View {
        HStack(spacing: 6) {
            if showsBar {
                Capsule()
                    .frame(width: 5)
                    .widgetAccentable()
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if let icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                        .lineLimit(1)
                }
                .font(titleFont)
                .widgetAccentable()

                Text(subtitle)
                    .font(bodyFont)
                    .lineLimit(1)

                if let detail {
                    HStack(spacing: 4) {
                        if let detailIcon {
                            Image(systemName: detailIcon)
                        }
                        Text(detail)
                            .lineLimit(1)
                    }
                    .font(bodyFont)
                    .foregroundStyle(.secondary)
                }
            }
            .tracking(-0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, subtitle, detail].compactMap { $0 }.joined(separator: ", "))
    }
}
