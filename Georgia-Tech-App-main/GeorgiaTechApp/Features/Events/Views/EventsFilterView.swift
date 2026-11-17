import SwiftUI

struct EventsFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isFilteringDate: Bool
    @Binding var selectedDate: Date
    @Binding var sortOrder: EventFeedSortOrder
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    Toggle("Filter by date", isOn: $isFilteringDate)
                        .accessibilityLabel("Filter events to a selected date")
                    if isFilteringDate {
                        DatePicker("Event date", selection: $selectedDate, displayedComponents: .date)
                            .accessibilityLabel("Event date")
                    }
                }
                Section("Sort") {
                    Picker("Order", selection: $sortOrder) {
                        ForEach(EventFeedSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .accessibilityLabel("Sort events")
                }
                Section {
                    Button("Reset filters", action: onReset)
                        .accessibilityLabel("Reset all event filters")
                }
            }
            .font(.gtBody1)
            .navigationTitle("Event Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Apply filters and close")
                }
            }
        }
        .tint(Color.gtPrimaryText)
    }
}
