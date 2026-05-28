import Foundation
import EventKit

final class AppleCalendarService: CalendarSourceProvider {
    private let store = EKEventStore()

    /// True if we currently have full read access to calendar events.
    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Prompts the user for calendar access. Returns whether access was granted.
    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    var disabledCalendarIDs: Set<String> = []

    func fetchCalendars() -> [CalendarInfo] {
        store.calendars(for: .event).map { cal in
            CalendarInfo(id: cal.calendarIdentifier,
                         title: cal.title,
                         color: cal.color,
                         accountName: cal.source.title)
        }
    }

    func fetchUpcomingEvents() async throws -> [CalendarEvent] {
        let now          = Date()
        let oneHourLater = now.addingTimeInterval(3_600)

        let allCals = store.calendars(for: .event)
        let filteredCals: [EKCalendar]? = disabledCalendarIDs.isEmpty
            ? nil
            : allCals.filter { !disabledCalendarIDs.contains($0.calendarIdentifier) }

        let predicate = store.predicateForEvents(withStart: now,
                                                 end:       oneHourLater,
                                                 calendars: filteredCals)
        let ekEvents = store.events(matching: predicate)
        return ekEvents.map { e in
            let hasOthers = (e.attendees ?? []).contains { !$0.isCurrentUser }
            return CalendarEvent(
                id:                 e.eventIdentifier ?? UUID().uuidString,
                title:              e.title ?? "Untitled",
                startDate:          e.startDate,
                endDate:            e.endDate,
                hasOtherAttendees:  hasOthers,
                participants:       participantString(for: e)
            )
        }
    }

    private func participantString(for event: EKEvent) -> String? {
        let names = (event.attendees ?? [])
            .filter { !$0.isCurrentUser }
            .compactMap { p -> String? in
                guard let name = p.name, !name.isEmpty else { return nil }
                return name
            }
        guard !names.isEmpty else { return nil }
        switch names.count {
        case 1:  return "with \(names[0])"
        case 2:  return "with \(names[0]) and \(names[1])"
        default: return "with \(names[0]), \(names[1]) +\(names.count - 2) more"
        }
    }
}
