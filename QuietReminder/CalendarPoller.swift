import Foundation

@MainActor
final class CalendarPoller {
    var alertMinutesBefore: Int
    var onMeetingSoon: ((CalendarEvent, Int) -> Void)?

    private let service: any CalendarSourceProvider
    private var timer: Timer?
    private var notifiedIDs: Set<String> = []
    private var snoozedUntil: [String: Date] = [:]

    init(service: any CalendarSourceProvider, alertMinutesBefore: Int) {
        self.service = service
        self.alertMinutesBefore = alertMinutesBefore
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

    func snooze(eventID: String, minutes: Int) {
        notifiedIDs.remove(eventID)
        snoozedUntil[eventID] = Date().addingTimeInterval(Double(minutes) * 60)
    }

    // MARK: Private

    private func poll() {
        Task {
            guard let events = try? await service.fetchUpcomingEvents() else { return }

            let now = Date()
            let low  = alertMinutesBefore - 1
            let high = alertMinutesBefore + 1

            for event in events {
                let minutes = Int(event.startDate.timeIntervalSince(now) / 60)

                // Snooze expired — re-alert regardless of lead-time window
                if let snoozeEnd = snoozedUntil[event.id], now >= snoozeEnd {
                    snoozedUntil.removeValue(forKey: event.id)
                    notifiedIDs.insert(event.id)
                    onMeetingSoon?(event, minutes)
                    continue
                }

                // Skip if still snoozed
                if snoozedUntil[event.id] != nil { continue }

                // Normal lead-time alert
                guard minutes >= low,
                      minutes <= high,
                      !notifiedIDs.contains(event.id) else { continue }

                notifiedIDs.insert(event.id)
                onMeetingSoon?(event, minutes)
            }
        }
    }
}
