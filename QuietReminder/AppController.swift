import Foundation
import AppKit
import Combine
import ServiceManagement

@MainActor
final class AppController: ObservableObject {
    @Published var hasAppleAccess: Bool = false

    @Published var flightDuration: Double {
        didSet { let v = flightDuration; Task { @MainActor in UserDefaults.standard.set(v, forKey: "flightDuration") } }
    }
    @Published var alertMinutesBefore: Int {
        didSet {
            UserDefaults.standard.set(alertMinutesBefore, forKey: "alertMinutesBefore")
            poller?.alertThresholds = activeThresholds
        }
    }
    @Published var earlyAlertMinutes: Int {
        didSet {
            UserDefaults.standard.set(earlyAlertMinutes, forKey: "earlyAlertMinutes")
            poller?.alertThresholds = activeThresholds
        }
    }
    @Published var snoozeMinutes: Int {
        didSet { let v = snoozeMinutes; Task { @MainActor in UserDefaults.standard.set(v, forKey: "snoozeMinutes") } }
    }
    @Published var screenPositionPercent: Double {
        didSet { let v = screenPositionPercent; Task { @MainActor in UserDefaults.standard.set(v, forKey: "screenPositionPercent") } }
    }
    @Published var playSound: Bool {
        didSet { let v = playSound; Task { @MainActor in UserDefaults.standard.set(v, forKey: "playSound") } }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            let enable = launchAtLogin
            Task { @MainActor in
                if enable { try? SMAppService.mainApp.register() }
                else       { try? SMAppService.mainApp.unregister() }
            }
        }
    }
    @Published var skipSoloEvents: Bool {
        didSet {
            let v = skipSoloEvents
            Task { @MainActor [weak self] in
                UserDefaults.standard.set(v, forKey: "skipSoloEvents")
                self?.poller?.skipSoloEvents = v
            }
        }
    }
    @Published var disabledCalendarIDs: Set<String> {
        didSet {
            let v = disabledCalendarIDs
            Task { @MainActor [weak self] in
                UserDefaults.standard.set(Array(v), forKey: "disabledCalendarIDs")
                self?.appleService.disabledCalendarIDs = v
            }
        }
    }
    @Published var availableCalendars: [CalendarInfo] = []
    @Published var airplaneTheme: AirplaneTheme {
        didSet { UserDefaults.standard.set(airplaneTheme.rawValue, forKey: "airplaneTheme") }
    }

    static let slowSpeed:   Double = 22
    static let normalSpeed: Double = 14
    static let fastSpeed:   Double = 8

    private let appleService = AppleCalendarService()
    private var poller: CalendarPoller?
    private var overlayWindows: [(eventID: String, window: AirplaneOverlayWindow)] = []
    private let preferencesController = PreferencesWindowController()

    private var activeThresholds: [Int] {
        var thresholds = [alertMinutesBefore]
        if earlyAlertMinutes > alertMinutesBefore && earlyAlertMinutes > 0 {
            thresholds.insert(earlyAlertMinutes, at: 0)
        }
        return thresholds  // already sorted descending
    }

    init() {
        let savedFlight = UserDefaults.standard.double(forKey: "flightDuration")
        self.flightDuration = savedFlight > 0 ? savedFlight : Self.normalSpeed

        self.alertMinutesBefore  = (UserDefaults.standard.object(forKey: "alertMinutesBefore")  as? Int)    ?? 5
        self.earlyAlertMinutes   = (UserDefaults.standard.object(forKey: "earlyAlertMinutes")    as? Int)    ?? 0
        self.snoozeMinutes       = (UserDefaults.standard.object(forKey: "snoozeMinutes")        as? Int)    ?? 5
        self.playSound           = (UserDefaults.standard.object(forKey: "playSound")            as? Bool)   ?? true
        self.launchAtLogin       = SMAppService.mainApp.status == .enabled
        self.skipSoloEvents      = (UserDefaults.standard.object(forKey: "skipSoloEvents")      as? Bool)   ?? false
        let savedTheme = UserDefaults.standard.string(forKey: "airplaneTheme") ?? ""
        self.airplaneTheme = AirplaneTheme(rawValue: savedTheme) ?? .classic

        let savedDisabled = UserDefaults.standard.stringArray(forKey: "disabledCalendarIDs") ?? []
        self.disabledCalendarIDs = Set(savedDisabled)

        let savedPos = UserDefaults.standard.double(forKey: "screenPositionPercent")
        self.screenPositionPercent = savedPos > 0 ? savedPos : 0.65

        hasAppleAccess = appleService.hasAccess
        appleService.disabledCalendarIDs = self.disabledCalendarIDs
        startPollingIfReady()
        if hasAppleAccess { availableCalendars = appleService.fetchCalendars() }
    }

    // MARK: Public

    func requestAppleAccess() {
        Task {
            let granted = await appleService.requestAccess()
            await MainActor.run {
                self.hasAppleAccess = granted
                self.startPollingIfReady()
                if granted { self.availableCalendars = self.appleService.fetchCalendars() }
            }
        }
    }

    func testAirplane() {
        let fake = CalendarEvent(
            id:                UUID().uuidString,
            title:             "Test Meeting",
            startDate:         Date().addingTimeInterval(Double(alertMinutesBefore) * 60),
            endDate:           Date().addingTimeInterval(Double(alertMinutesBefore) * 60 + 1800),
            hasOtherAttendees: true,
            participants:      "with John, Jane +2 more"
        )
        handleBatch([(fake, alertMinutesBefore)])
    }

    func openPreferences() {
        NSApp.keyWindow?.orderOut(nil)
        preferencesController.open(with: self)
    }

    func snooze(eventID: String) {
        poller?.snooze(eventID: eventID, minutes: snoozeMinutes)
    }

    // MARK: Private

    private func startPollingIfReady() {
        poller?.stop()
        poller = nil
        guard hasAppleAccess else { return }

        let p = CalendarPoller(service: appleService, alertThresholds: activeThresholds)
        p.skipSoloEvents = skipSoloEvents
        p.onMeetingsSoon = { [weak self] batch in self?.handleBatch(batch) }
        p.start()
        poller = p
    }

    // Stagger multiple simultaneous meetings 5 seconds apart.
    private func handleBatch(_ events: [(event: CalendarEvent, minutesUntil: Int)]) {
        for (index, item) in events.enumerated() {
            let delay = Double(index) * 5.0
            Task {
                if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                showAirplaneNow(for: item.event, minutesUntil: item.minutesUntil)
            }
        }
    }

    private func showAirplaneNow(for event: CalendarEvent, minutesUntil: Int) {
        let duration  = flightDuration
        let eventID   = event.id
        let yPos      = screenPositionPercent
        let theme     = airplaneTheme

        for screen in NSScreen.screens {
            let window = AirplaneOverlayWindow(
                screen:           screen,
                meetingTitle:     event.title,
                participants:     event.participants,
                minutesUntil:     minutesUntil,
                flightDuration:   duration,
                theme:            theme,
                yPositionPercent: yPos,
                onSnooze:         { [weak self] in
                    self?.snooze(eventID: eventID)
                    self?.closeWindows(for: eventID)
                }
            )
            window.orderFront(nil)
            overlayWindows.append((eventID: eventID, window: window))
        }

        if playSound { NSSound(named: NSSound.Name("Ping"))?.play() }

        Task {
            try? await Task.sleep(for: .seconds(duration + 1.5))
            closeWindows(for: eventID)
        }
    }

    private func closeWindows(for eventID: String) {
        overlayWindows.filter { $0.eventID == eventID }.forEach { $0.window.close() }
        overlayWindows.removeAll { $0.eventID == eventID }
    }
}
