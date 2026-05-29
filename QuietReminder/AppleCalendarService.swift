import Foundation
import EventKit
import OSLog

private let logger = Logger(subsystem: "app.quiet.QuietReminder", category: "Calendar")

final class AppleCalendarService: CalendarSourceProvider {
    private let store = EKEventStore()

    /// True if we currently have full read access to calendar events.
    var hasAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .fullAccess || status == .authorized
    }

    /// Prompts the user for calendar access. Returns whether access was granted.
    func requestAccess() async -> Bool {
        let before = EKEventStore.authorizationStatus(for: .event)
        logger.info("requestAccess called — status before: \(before.rawValue)")
        do {
            let granted = try await store.requestFullAccessToEvents()
            let after = EKEventStore.authorizationStatus(for: .event)
            logger.info("requestFullAccessToEvents returned: \(granted) — status after: \(after.rawValue)")
            return granted
        } catch {
            logger.error("requestFullAccessToEvents threw: \(error)")
            return false
        }
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
                participants:       participantString(for: e),
                joinURL:            extractMeetingURL(from: e),
                calendarColor:      e.calendar.color
            )
        }
    }

    func fetchUpcomingEventsExtended() async throws -> [CalendarEvent] {
        let now = Date()
        let fourHours = now.addingTimeInterval(4 * 3600)
        let allCals = store.calendars(for: .event)
        let filteredCals: [EKCalendar]? = disabledCalendarIDs.isEmpty
            ? nil
            : allCals.filter { !disabledCalendarIDs.contains($0.calendarIdentifier) }
        let predicate = store.predicateForEvents(withStart: now, end: fourHours, calendars: filteredCals)
        let ekEvents = store.events(matching: predicate)
        return ekEvents.map { e in
            let hasOthers = (e.attendees ?? []).contains { !$0.isCurrentUser }
            return CalendarEvent(
                id: e.eventIdentifier ?? UUID().uuidString,
                title: e.title ?? "Meeting",
                startDate: e.startDate,
                endDate: e.endDate,
                hasOtherAttendees: hasOthers,
                participants: nil,
                joinURL: extractMeetingURL(from: e)
            )
        }
    }

    func fetchOngoingEvents() async throws -> [CalendarEvent] {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-2 * 3600)
        let allCals = store.calendars(for: .event)
        let filteredCals: [EKCalendar]? = disabledCalendarIDs.isEmpty
            ? nil
            : allCals.filter { !disabledCalendarIDs.contains($0.calendarIdentifier) }
        let predicate = store.predicateForEvents(withStart: twoHoursAgo, end: now, calendars: filteredCals)
        let ekEvents = store.events(matching: predicate)
        return ekEvents.compactMap { e in
            guard e.endDate > now else { return nil }
            let hasOthers = (e.attendees ?? []).contains { !$0.isCurrentUser }
            return CalendarEvent(
                id: e.eventIdentifier ?? UUID().uuidString,
                title: e.title ?? "Meeting",
                startDate: e.startDate,
                endDate: e.endDate,
                hasOtherAttendees: hasOthers,
                participants: participantString(for: e),
                joinURL: extractMeetingURL(from: e)
            )
        }
    }

    func fetchEventsRestOfDay() async throws -> [CalendarEvent] {
        let now = Date()
        let cal = Calendar.current
        guard let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) else { return [] }
        let allCals = store.calendars(for: .event)
        let filteredCals: [EKCalendar]? = disabledCalendarIDs.isEmpty
            ? nil
            : allCals.filter { !disabledCalendarIDs.contains($0.calendarIdentifier) }
        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: filteredCals)
        let ekEvents = store.events(matching: predicate)
        return ekEvents
            .sorted { $0.startDate < $1.startDate }
            .prefix(6)
            .map { e in
                CalendarEvent(
                    id: e.eventIdentifier ?? UUID().uuidString,
                    title: e.title ?? "Meeting",
                    startDate: e.startDate,
                    endDate: e.endDate,
                    hasOtherAttendees: (e.attendees ?? []).contains { !$0.isCurrentUser },
                    participants: nil,
                    joinURL: nil,
                    calendarColor: e.calendar.color
                )
            }
    }

    private func extractMeetingURL(from event: EKEvent) -> URL? {
        // event.url is set from the ICS URL: field — usually the direct meeting link
        if let url = event.url {
            if isMeetingURL(url) { return url }
            // event.url itself might be a protection wrapper — fall through to decode it
            if let decoded = unwrapProtectedURL(url.absoluteString) { return decoded }
        }

        let searchTargets: [String] = [event.notes, event.location].compactMap { $0 }
        for text in searchTargets {
            if let url = extractMeetingURL(from: text) { return url }
        }
        return nil
    }

    private func extractMeetingURL(from text: String) -> URL? {
        // 1. Microsoft SafeLinks: decode url= query param
        let safelinkPattern = "https://[\\w.-]+\\.safelinks\\.protection\\.outlook\\.com/[^\\s<>\"]*"
        if let range = text.range(of: safelinkPattern, options: .regularExpression) {
            let raw = String(text[range])
            if let decoded = unwrapProtectedURL(raw) { return decoded }
            // fallback: return SafeLinks URL itself (browser will redirect)
            if let url = URL(string: raw) { return url }
        }

        // 2. Mimecast: decode url= query param if present, else return as-is (browser redirects)
        let mimecastPattern = "https://[\\w.-]+\\.mimecastprotect\\.com/[^\\s<>\"]*"
        if let range = text.range(of: mimecastPattern, options: .regularExpression) {
            let raw = String(text[range])
            if let decoded = unwrapProtectedURL(raw) { return decoded }
            if let url = URL(string: raw) { return url }
        }

        // 3. Angle-bracket wrapped URLs (Outlook/Teams invite format: <https://...>)
        let angleBracketPattern = "<(https://[^\\s<>]+)>"
        if let regex = try? NSRegularExpression(pattern: angleBracketPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let urlRange = Range(match.range(at: 1), in: text) {
            let raw = String(text[urlRange])
            if let decoded = unwrapProtectedURL(raw) { return decoded }
            if let url = URL(string: raw), isMeetingURL(url) { return url }
        }

        // 4. Direct meeting URLs
        let patterns = [
            "https://[\\w.-]+\\.zoom\\.us/j/[^\\s<>]+",
            "https://meet\\.google\\.com/[a-z-]+",
            "https://teams\\.microsoft\\.com/l/meetup-join/[^\\s<>]+",
            "https://[\\w.-]+\\.webex\\.com/[^\\s<>]+",
            "https://meetings\\.ringcentral\\.com/[^\\s<>]+",
            "https://[\\w.-]+\\.ringcentral\\.com/[^\\s<>]+",
            "https://[\\w.-]+\\.gotomeeting\\.com/join/[^\\s<>]+",
            "https://meet\\.goto\\.com/[^\\s<>]+",
            "https://bluejeans\\.com/[^\\s<>]+",
            "https://whereby\\.com/[^\\s<>]+",
            "https://meet\\.jit\\.si/[^\\s<>]+",
            "https://join\\.skype\\.com/[^\\s<>]+",
            "https://[\\w.-]+\\.chime\\.aws/[^\\s<>]+"
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression),
               let url = URL(string: String(text[range])) {
                return url
            }
        }
        return nil
    }

    /// Decodes the inner URL from SafeLinks/Mimecast/similar wrappers via the `url=` query param.
    private func unwrapProtectedURL(_ raw: String) -> URL? {
        guard let components = URLComponents(string: raw),
              let innerEncoded = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let innerURL = URL(string: innerEncoded)
        else { return nil }
        return isMeetingURL(innerURL) ? innerURL : nil
    }

    private func isMeetingURL(_ url: URL) -> Bool {
        let host = url.host ?? ""
        let meetingHosts = [
            "teams.microsoft.com", "zoom.us", "meet.google.com",
            "webex.com", "ringcentral.com", "gotomeeting.com",
            "meet.goto.com", "bluejeans.com", "whereby.com",
            "meet.jit.si", "join.skype.com", "chime.aws"
        ]
        return meetingHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
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
