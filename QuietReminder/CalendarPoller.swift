import Foundation

@MainActor
final class CalendarPoller {
    // All thresholds sorted descending (e.g. [10, 5]). Only one threshold fires per event per poll.
    var alertThresholds: [Int]
    var skipSoloEvents: Bool = false
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Int = 22
    var quietHoursEnd: Int = 8
    var onMeetingsSoon: ([(event: CalendarEvent, minutesUntil: Int)]) -> Void = { _ in }
    var meetingEndWarningEnabled: Bool = false
    var meetingEndWarningMinutes: Int  = 5
    var onMeetingsEndingSoon: ([(event: CalendarEvent, minutesUntilEnd: Int)]) -> Void = { _ in }
    var onPollComplete: (() -> Void)?
    private var notifiedEndKeys: Set<String> = []

    private let service: any CalendarSourceProvider
    private var timer: Timer?
    private var notifiedKeys: Set<String> = []   // "\(eventID)_\(threshold)"
    private var snoozedUntil: [String: Date] = [:]

    init(service: any CalendarSourceProvider, alertThresholds: [Int]) {
        self.service = service
        self.alertThresholds = alertThresholds.sorted(by: >)
    }

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            DispatchQueue.main.async { [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // Remove threshold keys so event can re-alert after snooze duration.
    func snooze(eventID: String, minutes: Int) {
        for threshold in alertThresholds {
            notifiedKeys.remove("\(eventID)_\(threshold)")
        }
        snoozedUntil[eventID] = Date().addingTimeInterval(Double(minutes) * 60)
    }

    // Permanently suppress all future alerts for this event.
    func dismiss(eventID: String) {
        snoozedUntil.removeValue(forKey: eventID)
        alertThresholds.forEach { notifiedKeys.insert("\(eventID)_\($0)") }
    }

    // MARK: Private

    private func isInQuietHours() -> Bool {
        guard quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return quietHoursStart > quietHoursEnd
            ? (hour >= quietHoursStart || hour < quietHoursEnd)
            : (hour >= quietHoursStart && hour < quietHoursEnd)
    }

    private func poll() {
        Task {
            if self.isInQuietHours() { return }
            guard let events = try? await service.fetchUpcomingEvents() else { return }
            let now = Date()
            var toFire: [(CalendarEvent, Int)] = []

            let filtered = skipSoloEvents ? events.filter { $0.hasOtherAttendees } : events
            for event in filtered {
                let minutes = Int(event.startDate.timeIntervalSince(now) / 60)

                // Snooze expired — re-alert once, then lock all thresholds
                if let snoozeEnd = snoozedUntil[event.id], now >= snoozeEnd {
                    snoozedUntil.removeValue(forKey: event.id)
                    alertThresholds.forEach { notifiedKeys.insert("\(event.id)_\($0)") }
                    toFire.append((event, minutes))
                    continue
                }

                if snoozedUntil[event.id] != nil { continue }

                // Check each threshold highest-first; only one fires per event per poll
                for threshold in alertThresholds {
                    let key = "\(event.id)_\(threshold)"
                    let lo = threshold == 0 ? 0 : max(0, threshold - 1)
                    let hi = threshold == 0 ? 0 : threshold + 1
                    guard minutes >= lo,
                          minutes <= hi,
                          !notifiedKeys.contains(key) else { continue }
                    notifiedKeys.insert(key)
                    toFire.append((event, minutes))
                    break
                }
            }

            if !toFire.isEmpty { onMeetingsSoon(toFire) }

            // Meeting end warnings
            if self.meetingEndWarningEnabled {
                let ongoingEvents = (try? await service.fetchOngoingEvents()) ?? []
                let ongoingFiltered = skipSoloEvents ? ongoingEvents.filter { $0.hasOtherAttendees } : ongoingEvents
                var toEndFire: [(CalendarEvent, Int)] = []
                for event in ongoingFiltered {
                    let minutesUntilEnd = Int(event.endDate.timeIntervalSince(now) / 60)
                    let endKey = "\(event.id)_end_\(meetingEndWarningMinutes)"
                    let lo = max(0, meetingEndWarningMinutes - 1)
                    let hi = meetingEndWarningMinutes + 1
                    guard minutesUntilEnd >= lo, minutesUntilEnd <= hi,
                          !notifiedEndKeys.contains(endKey) else { continue }
                    notifiedEndKeys.insert(endKey)
                    toEndFire.append((event, minutesUntilEnd))
                }
                if !toEndFire.isEmpty { onMeetingsEndingSoon(toEndFire) }
            }

            onPollComplete?()
        }
    }
}
