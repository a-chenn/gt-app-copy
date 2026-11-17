import EventKit
import Foundation

/// Uses write-only calendar access; the app never reads personal events.
@MainActor
enum EventCalendarService {
    enum AddResult {
        case added
        case permissionDenied
        case failed
    }

    static func addToCalendar(_ event: Event) async -> AddResult {
        let store = EKEventStore()
        let authorization = EKEventStore.authorizationStatus(for: .event)
        guard authorization != .denied && authorization != .restricted else {
            return .permissionDenied
        }
        do {
            guard try await store.requestWriteOnlyAccessToEvents() else {
                return .permissionDenied
            }
            guard let calendar = store.defaultCalendarForNewEvents else { return .failed }
            let calendarEvent = EKEvent(eventStore: store)
            calendarEvent.calendar = calendar
            calendarEvent.title = event.title
            calendarEvent.startDate = event.startDate
            calendarEvent.endDate = max(event.endDate, event.startDate.addingTimeInterval(60))
            calendarEvent.timeZone = TimeZone(identifier: event.timezone)
            calendarEvent.location = event.location
            calendarEvent.notes = event.body.isEmpty ? event.summary : event.body
            try store.save(calendarEvent, span: .thisEvent)
            return .added
        } catch {
            if EKEventStore.authorizationStatus(for: .event) == .denied {
                return .permissionDenied
            }
            return .failed
        }
    }
}
