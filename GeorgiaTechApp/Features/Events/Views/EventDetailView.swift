//
//  EventDetailView.swift
//  GeorgiaTechApp
//

import SwiftUI

struct EventDetailView: View {
    let event: Event

    @State private var hasReminder = false
    @State private var reminderHint: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Events carry no artwork, so the heading stands on its
                // own — no gradient block standing in for a photo.
                // No eyebrow: the category capsules below already say it,
                // and the title should be the first thing read.
                GTDetailHero(
                    title: event.title,
                    accessibilityText: "\(event.title), \(timeText)"
                ) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(timeText)
                            .font(.gtHeading6)
                            .tracking(1)
                            .foregroundStyle(Color.gtDarkGold)

                        if let location = event.location, !location.isEmpty {
                            Label(location, systemImage: "mappin")
                                .font(.gtBody3)
                                .foregroundStyle(Color.gtSecondaryText)
                        }
                    }
                }

                reminderButton

                if !event.eventCategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(event.eventCategories, id: \.self) { category in
                                Text(category)
                                    .font(.gtHeading6)
                                    .tracking(1)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Color.gtPrimaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color.gtGold.opacity(0.18), in: .capsule)
                                    .overlay {
                                        Capsule().strokeBorder(
                                            Color.gtGold.opacity(0.45), lineWidth: 1)
                                    }
                            }
                        }
                    }
                }

                // `body` is the full write-up the feed already sends and
                // nothing was showing; summary is the fallback so the
                // card is never empty and never says it twice.
                let story = event.body.isEmpty ? event.summary : event.body
                if !story.isEmpty {
                    GTBodyText(text: story)
                        .gtCard()
                }

                if !event.groups.isEmpty {
                    detailBlock("Hosted by", value: event.groups.joined(separator: ", "))
                }

                if let contact = event.contact, !contact.isEmpty {
                    detailBlock("Contact", value: contact)
                }

                if !event.relatedLinks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        GTSectionHeader("Links")
                        ForEach(event.relatedLinks) { link in
                            if let url = URL(string: link.url) {
                                ExternalLinkButton(url: url) {
                                    Text(link.title.isEmpty ? link.url : link.title)
                                        .font(.gtBody2)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .gtScreenBackground()
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            hasReminder = await EventReminders.hasReminder(for: event)
        }
    }

    // MARK: - Reminder

    @ViewBuilder
    private var reminderButton: some View {
        if event.startDate > Date() && NotificationService.shared.isPreferred(.campusEvents) {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    Task {
                        if hasReminder {
                            EventReminders.cancelReminder(for: event)
                            hasReminder = false
                            reminderHint = nil
                        } else {
                            switch await EventReminders.scheduleReminder(for: event) {
                            case .scheduled:
                                hasReminder = true
                                reminderHint = nil
                            case .permissionDenied:
                                reminderHint = "Enable notifications in Settings to get reminders."
                            case .startsTooSoon:
                                reminderHint = "This event starts in under \(EventReminders.minutesBefore) minutes."
                            case .failed:
                                reminderHint = "Couldn't schedule the reminder. Try again."
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: hasReminder ? "bell.fill" : "bell")
                        Text(hasReminder ? "Reminder Set" : "Remind Me")
                    }
                    .font(.gtHeading5)
                    .foregroundStyle(hasReminder ? Color.gtNavy : Color.gtPrimaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        if hasReminder {
                            Capsule().fill(Color.gtGold)
                        } else {
                            Capsule().strokeBorder(Color.gtSecondaryText.opacity(0.4), lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasReminder
                    ? "Cancel reminder for \(event.title)"
                    : "Remind me 30 minutes before \(event.title)")
                .accessibilityAddTraits(hasReminder ? .isSelected : [])

                if let reminderHint {
                    Text(reminderHint)
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtSecondaryText)
                }
            }
        }
    }

    private var timeText: String {
        let start = event.startDate
        let end = event.endDate
        if Calendar.current.isDate(start, inSameDayAs: end) {
            let day = start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            let times = "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
            return "\(day), \(times)"
        }
        return "\(start.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .abbreviated, time: .shortened))"
    }

    private func detailBlock(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GTSectionHeader(label)
            Text(value)
                .font(.gtBody2)
                .foregroundStyle(Color.gtSecondaryText)
        }
    }
}
