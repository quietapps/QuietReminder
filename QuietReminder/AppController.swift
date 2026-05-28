import Foundation
import AppKit
import Combine

@MainActor
final class AppController: ObservableObject {
    @Published var hasAppleAccess: Bool = false

    @Published var flightDuration: Double {
        didSet { UserDefaults.standard.set(flightDuration, forKey: "flightDuration") }
    }
    @Published var alertMinutesBefore: Int {
        didSet {
            UserDefaults.standard.set(alertMinutesBefore, forKey: "alertMinutesBefore")
            poller?.alertMinutesBefore = alertMinutesBefore
        }
    }
    @Published var snoozeMinutes: Int {
        didSet { UserDefaults.standard.set(snoozeMinutes, forKey: "snoozeMinutes") }
    }

    static let slowSpeed:   Double = 22
    static let normalSpeed: Double = 14
    static let fastSpeed:   Double = 8

    private let appleService = AppleCalendarService()
    private var poller: CalendarPoller?
    private var overlayWindows: [(eventID: String, window: AirplaneOverlayWindow)] = []

    init() {
        let savedFlight = UserDefaults.standard.double(forKey: "flightDuration")
        self.flightDuration = savedFlight > 0 ? savedFlight : Self.normalSpeed

        let savedAlert = UserDefaults.standard.integer(forKey: "alertMinutesBefore")
        self.alertMinutesBefore = savedAlert > 0 ? savedAlert : 5

        let savedSnooze = UserDefaults.standard.integer(forKey: "snoozeMinutes")
        self.snoozeMinutes = savedSnooze > 0 ? savedSnooze : 5

        hasAppleAccess = appleService.hasAccess
        startPollingIfReady()
    }

    // MARK: Public

    func requestAppleAccess() {
        Task {
            let granted = await appleService.requestAccess()
            await MainActor.run {
                self.hasAppleAccess = granted
                self.startPollingIfReady()
            }
        }
    }

    func testAirplane() {
        let fake = CalendarEvent(
            id:        UUID().uuidString,
            title:     "Test Meeting",
            startDate: Date().addingTimeInterval(Double(alertMinutesBefore) * 60),
            endDate:   Date().addingTimeInterval(Double(alertMinutesBefore) * 60 + 1800)
        )
        showAirplane(for: fake, minutesUntil: alertMinutesBefore)
    }

    func snooze(eventID: String) {
        poller?.snooze(eventID: eventID, minutes: snoozeMinutes)
    }

    // MARK: Private

    private func startPollingIfReady() {
        poller?.stop()
        poller = nil
        guard hasAppleAccess else { return }

        let p = CalendarPoller(service: appleService, alertMinutesBefore: alertMinutesBefore)
        p.onMeetingSoon = { [weak self] event, minutes in
            self?.showAirplane(for: event, minutesUntil: minutes)
        }
        p.start()
        poller = p
    }

    private func showAirplane(for event: CalendarEvent, minutesUntil: Int) {
        let duration = flightDuration
        let eventID  = event.id

        DispatchQueue.main.async {
            for screen in NSScreen.screens {
                let window = AirplaneOverlayWindow(
                    screen:         screen,
                    meetingTitle:   event.title,
                    minutesUntil:   minutesUntil,
                    flightDuration: duration,
                    onSnooze:       { [weak self] in
                        self?.snooze(eventID: eventID)
                        self?.closeWindows(for: eventID)
                    }
                )
                window.makeKeyAndOrderFront(nil)
                self.overlayWindows.append((eventID: eventID, window: window))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 1.5) {
                self.closeWindows(for: eventID)
            }
        }
    }

    private func closeWindows(for eventID: String) {
        overlayWindows.filter { $0.eventID == eventID }.forEach { $0.window.close() }
        overlayWindows.removeAll { $0.eventID == eventID }
    }
}
