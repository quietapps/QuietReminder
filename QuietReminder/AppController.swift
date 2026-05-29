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
    @Published var alertThresholds: [Int] {
        didSet {
            let v = alertThresholds
            Task { @MainActor in UserDefaults.standard.set(v, forKey: "alertThresholds") }
            poller?.alertThresholds = v.sorted(by: >)
        }
    }
    @Published var quietHoursEnabled: Bool {
        didSet {
            let v = quietHoursEnabled
            Task { @MainActor in UserDefaults.standard.set(v, forKey: "quietHoursEnabled") }
            poller?.quietHoursEnabled = v
        }
    }
    @Published var quietHoursStart: Int {
        didSet {
            let v = quietHoursStart
            Task { @MainActor in UserDefaults.standard.set(v, forKey: "quietHoursStart") }
            poller?.quietHoursStart = v
        }
    }
    @Published var quietHoursEnd: Int {
        didSet {
            let v = quietHoursEnd
            Task { @MainActor in UserDefaults.standard.set(v, forKey: "quietHoursEnd") }
            poller?.quietHoursEnd = v
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

    @Published var showMenuBarCountdown: Bool {
        didSet { UserDefaults.standard.set(showMenuBarCountdown, forKey: "showMenuBarCountdown"); updateCountdown() }
    }
    @Published var nextMeetingMinutes: Int? = nil
    @Published var nextMeetingTitle: String? = nil

    @Published var meetingEndWarningEnabled: Bool {
        didSet {
            let v = meetingEndWarningEnabled
            UserDefaults.standard.set(v, forKey: "meetingEndWarningEnabled")
            poller?.meetingEndWarningEnabled = v
        }
    }
    @Published var meetingEndWarningMinutes: Int {
        didSet {
            let v = meetingEndWarningMinutes
            UserDefaults.standard.set(v, forKey: "meetingEndWarningMinutes")
            poller?.meetingEndWarningMinutes = v
        }
    }

    @Published var showUpcomingEvents: Bool {
        didSet { UserDefaults.standard.set(showUpcomingEvents, forKey: "showUpcomingEvents") }
    }
    @Published var upcomingEvents: [CalendarEvent] = []

    @Published var showOnAllScreens: Bool {
        didSet { UserDefaults.standard.set(showOnAllScreens, forKey: "showOnAllScreens") }
    }
    @Published var selectedScreenName: String? {
        didSet { UserDefaults.standard.set(selectedScreenName, forKey: "selectedScreenName") }
    }
    @Published var alertSoundName: String {
        didSet { UserDefaults.standard.set(alertSoundName, forKey: "alertSoundName") }
    }
    @Published var showCalendarColors: Bool {
        didSet { UserDefaults.standard.set(showCalendarColors, forKey: "showCalendarColors") }
    }
    @Published var bannerOpacity: Double {
        didSet { UserDefaults.standard.set(bannerOpacity, forKey: "bannerOpacity") }
    }
    @Published var showEventTitleInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showEventTitleInMenuBar, forKey: "showEventTitleInMenuBar") }
    }
    @Published var useBannerCalendarColor: Bool {
        didSet { UserDefaults.standard.set(useBannerCalendarColor, forKey: "useBannerCalendarColor") }
    }

    static let slowSpeed:   Double = 22
    static let normalSpeed: Double = 14
    static let fastSpeed:   Double = 8
    static let activeScreenSentinel = "__active__"

    @Published var pausedUntil: Date? = nil
    private var pauseTimer: Timer?

    var isPaused: Bool {
        guard let until = pausedUntil else { return false }
        return Date() < until
    }

    var pauseStatusText: String? {
        guard let until = pausedUntil, Date() < until else { return nil }
        if until == .distantFuture { return "Paused" }
        let mins = Int(until.timeIntervalSinceNow / 60)
        if mins < 60 { return "Paused · \(mins)m left" }
        return "Paused · \(mins / 60)h left"
    }

    func pause(until date: Date) {
        pausedUntil = date
        pauseTimer?.invalidate()
        if date != .distantFuture {
            let t = Timer(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.resume() }
            }
            RunLoop.main.add(t, forMode: .common)
            pauseTimer = t
        }
    }

    func resume() {
        pausedUntil = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
    }

    private let appleService = AppleCalendarService()
    private var poller: CalendarPoller?
    private var overlayWindows: [(eventID: String, window: AirplaneOverlayWindow)] = []
    private let preferencesController = PreferencesWindowController()
    private var countdownTimer: Timer?

    init() {
        let savedFlight = UserDefaults.standard.double(forKey: "flightDuration")
        self.flightDuration = savedFlight > 0 ? savedFlight : Self.normalSpeed

        if let saved = UserDefaults.standard.array(forKey: "alertThresholds") as? [Int], !saved.isEmpty {
            self.alertThresholds = saved
        } else {
            let old = (UserDefaults.standard.object(forKey: "alertMinutesBefore") as? Int) ?? 5
            let early = (UserDefaults.standard.object(forKey: "earlyAlertMinutes") as? Int) ?? 0
            var thresholds = [old]
            if early > 0 && early != old { thresholds.insert(early, at: 0) }
            self.alertThresholds = thresholds
        }
        self.quietHoursEnabled = (UserDefaults.standard.object(forKey: "quietHoursEnabled") as? Bool) ?? false
        self.quietHoursStart   = (UserDefaults.standard.object(forKey: "quietHoursStart")   as? Int)  ?? 22
        self.quietHoursEnd     = (UserDefaults.standard.object(forKey: "quietHoursEnd")     as? Int)  ?? 8
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

        self.showMenuBarCountdown   = (UserDefaults.standard.object(forKey: "showMenuBarCountdown")   as? Bool) ?? false
        self.meetingEndWarningEnabled = (UserDefaults.standard.object(forKey: "meetingEndWarningEnabled") as? Bool) ?? false
        self.meetingEndWarningMinutes = (UserDefaults.standard.object(forKey: "meetingEndWarningMinutes") as? Int) ?? 5
        self.showUpcomingEvents     = (UserDefaults.standard.object(forKey: "showUpcomingEvents")     as? Bool) ?? true
        self.showOnAllScreens       = (UserDefaults.standard.object(forKey: "showOnAllScreens")       as? Bool) ?? true
        self.selectedScreenName     = UserDefaults.standard.string(forKey: "selectedScreenName")
        self.alertSoundName         = UserDefaults.standard.string(forKey: "alertSoundName") ?? "Ping"
        self.showCalendarColors     = (UserDefaults.standard.object(forKey: "showCalendarColors")     as? Bool) ?? true
        let savedOpacity            = UserDefaults.standard.double(forKey: "bannerOpacity")
        self.bannerOpacity          = savedOpacity > 0 ? savedOpacity : 1.0
        self.showEventTitleInMenuBar  = (UserDefaults.standard.object(forKey: "showEventTitleInMenuBar")  as? Bool) ?? false
        self.useBannerCalendarColor   = (UserDefaults.standard.object(forKey: "useBannerCalendarColor")   as? Bool) ?? false

        hasAppleAccess = appleService.hasAccess
        appleService.disabledCalendarIDs = self.disabledCalendarIDs
        startPollingIfReady()
        if hasAppleAccess { availableCalendars = appleService.fetchCalendars() }
        updateCountdown()
    }

    // MARK: Public

    func requestAppleAccess() {
        Task {
            let granted = await appleService.requestAccess()
            await MainActor.run {
                self.hasAppleAccess = granted
                self.startPollingIfReady()
                if granted {
                    self.availableCalendars = self.appleService.fetchCalendars()
                    self.updateCountdown()
                    self.refreshUpcomingEvents()
                }
            }
        }
    }

    func testAirplane() {
        let fake = CalendarEvent(
            id:                UUID().uuidString,
            title:             "Test Meeting",
            startDate:         Date().addingTimeInterval(Double(alertThresholds.first ?? 5) * 60),
            endDate:           Date().addingTimeInterval(Double(alertThresholds.first ?? 5) * 60 + 1800),
            hasOtherAttendees: true,
            participants:      "with John, Jane +2 more",
            joinURL:           URL(string: "https://google.com")
        )
        handleBatch([(fake, alertThresholds.first ?? 5)])
    }

    func openPreferences() {
        NSApp.keyWindow?.orderOut(nil)
        preferencesController.open(with: self)
    }

    func snooze(eventID: String) {
        if snoozeMinutes == 0 {
            poller?.dismiss(eventID: eventID)
        } else {
            poller?.snooze(eventID: eventID, minutes: snoozeMinutes)
        }
    }

    // MARK: Private

    private func startPollingIfReady() {
        poller?.stop()
        poller = nil
        guard hasAppleAccess else { return }

        let p = CalendarPoller(service: appleService, alertThresholds: alertThresholds)
        p.skipSoloEvents = skipSoloEvents
        p.quietHoursEnabled = quietHoursEnabled
        p.quietHoursStart   = quietHoursStart
        p.quietHoursEnd     = quietHoursEnd
        p.onMeetingsSoon = { [weak self] batch in self?.handleBatch(batch) }
        p.meetingEndWarningEnabled = meetingEndWarningEnabled
        p.meetingEndWarningMinutes = meetingEndWarningMinutes
        p.onMeetingsEndingSoon = { [weak self] batch in self?.handleEndWarningBatch(batch) }
        p.onPollComplete = { [weak self] in self?.refreshUpcomingEvents() }
        p.start()
        poller = p
    }

    // Stagger multiple simultaneous meetings 5 seconds apart.
    private func handleBatch(_ events: [(event: CalendarEvent, minutesUntil: Int)]) {
        guard !isPaused else { return }
        for (index, item) in events.enumerated() {
            let delay = Double(index) * 5.0
            Task {
                if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                showAirplaneNow(for: item.event, minutesUntil: item.minutesUntil)
            }
        }
    }

    private func handleEndWarningBatch(_ events: [(event: CalendarEvent, minutesUntilEnd: Int)]) {
        guard !isPaused else { return }
        for (index, item) in events.enumerated() {
            let delay = Double(index) * 5.0
            Task {
                if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                showAirplaneNow(for: item.event, minutesUntil: -item.minutesUntilEnd)
            }
        }
    }

    func updateCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        guard showMenuBarCountdown, hasAppleAccess else {
            nextMeetingMinutes = nil
            nextMeetingTitle = nil
            return
        }
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshCountdown() }
        }
        RunLoop.main.add(t, forMode: .common)
        countdownTimer = t
        refreshCountdown()
    }

    private func refreshCountdown() {
        Task {
            let events = (try? await appleService.fetchUpcomingEventsExtended()) ?? []
            let now = Date()
            let next = events.filter { $0.startDate > now }.min(by: { $0.startDate < $1.startDate })
            await MainActor.run {
                if let e = next {
                    self.nextMeetingMinutes = Int(e.startDate.timeIntervalSince(now) / 60)
                    self.nextMeetingTitle = e.title
                } else {
                    self.nextMeetingMinutes = nil
                    self.nextMeetingTitle = nil
                }
            }
        }
    }

    var menuBarCountdownText: String? {
        guard showMenuBarCountdown, let min = nextMeetingMinutes else { return nil }
        let timeStr: String
        if min <= 0 { timeStr = "Now" }
        else if min < 60 { timeStr = "in \(min)m" }
        else {
            let h = min / 60, m = min % 60
            timeStr = m == 0 ? "in \(h)h" : "in \(h)h\(m)m"
        }
        if showEventTitleInMenuBar, let title = nextMeetingTitle {
            let truncated = title.count > 20 ? String(title.prefix(20)) + "…" : title
            return "\(timeStr) · \(truncated)"
        }
        return timeStr
    }

    func refreshUpcomingEvents() {
        guard showUpcomingEvents, hasAppleAccess else { upcomingEvents = []; return }
        Task {
            let events = (try? await appleService.fetchEventsRestOfDay()) ?? []
            let filtered = skipSoloEvents ? events.filter { $0.hasOtherAttendees } : events
            await MainActor.run { self.upcomingEvents = Array(filtered.prefix(3)) }
        }
    }

    private func showAirplaneNow(for event: CalendarEvent, minutesUntil: Int) {
        let duration      = flightDuration
        let eventID       = event.id
        let yPos          = screenPositionPercent
        let theme         = airplaneTheme
        let opacity       = bannerOpacity
        let calColor      = useBannerCalendarColor ? event.calendarColor : nil
        let snoozeLabel   = snoozeMinutes > 0 ? "Snooze \(snoozeMinutes) min" : nil
        let joinURL       = event.joinURL

        let screens: [NSScreen]
        if showOnAllScreens {
            screens = NSScreen.screens
        } else if selectedScreenName == Self.activeScreenSentinel {
            let mouseLoc = NSEvent.mouseLocation
            let active = NSScreen.screens.first { $0.frame.contains(mouseLoc) }
                      ?? NSScreen.main
                      ?? NSScreen.screens[0]
            screens = [active]
        } else if let name = selectedScreenName,
                  let match = NSScreen.screens.first(where: { $0.localizedName == name }) {
            screens = [match]
        } else {
            screens = [NSScreen.main ?? NSScreen.screens[0]]
        }

        let maxWidth = screens.map(\.frame.width).max() ?? 1440
        let sharedAnim = AirplaneAnimController(screenWidth: maxWidth, flightDuration: duration)

        for screen in screens {
            let window = AirplaneOverlayWindow(
                screen:              screen,
                meetingTitle:        event.title,
                participants:        event.participants,
                minutesUntil:        minutesUntil,
                flightDuration:      duration,
                theme:               theme,
                yPositionPercent:    yPos,
                bannerOpacity:       opacity,
                calendarColor:       calColor,
                animController:      sharedAnim,
                onSnooze:         { [weak self] in
                    self?.snooze(eventID: eventID)
                    self?.closeWindows(for: eventID)
                },
                snoozeLabel:      snoozeLabel,
                onJoin:           joinURL.map { url in { NSWorkspace.shared.open(url) } }
            )
            window.orderFront(nil)
            overlayWindows.append((eventID: eventID, window: window))
        }

        sharedAnim.onComplete = { [weak self] in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                self?.closeWindows(for: eventID)
            }
        }
        sharedAnim.start()
        if playSound { NSSound(named: NSSound.Name(alertSoundName))?.play() }
    }

    private func closeWindows(for eventID: String) {
        overlayWindows.filter { $0.eventID == eventID }.forEach { $0.window.close() }
        overlayWindows.removeAll { $0.eventID == eventID }
    }
}
