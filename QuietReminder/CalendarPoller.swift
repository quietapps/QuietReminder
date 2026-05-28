import Foundation

@MainActor
final class CalendarPoller {
    // All thresholds sorted descending (e.g. [10, 5]). Only one threshold fires per event per poll.
    var alertThresholds: [Int]
    var skipSoloEvents: Bool = false
    var onMeetingsSoon: ([(event: CalendarEvent, minutesUntil: Int)]) -> Void = { _ in }

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

    // MARK: Private

    private func poll() {
        Task {
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
                    guard minutes >= threshold - 1,
                          minutes <= threshold + 1,
                          !notifiedKeys.contains(key) else { continue }
                    notifiedKeys.insert(key)
                    toFire.append((event, minutes))
                    break
                }
            }

            if !toFire.isEmpty { onMeetingsSoon(toFire) }
        }
    }
}
