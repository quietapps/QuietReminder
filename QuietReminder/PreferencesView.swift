import SwiftUI

// MARK: - Reusable card + row components

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(icon: String,
         iconColor: Color = .blue,
         title: String,
         subtitle: String? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.icon      = icon
        self.iconColor = iconColor
        self.title     = title
        self.subtitle  = subtitle
        self.trailing  = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Tab definition

private enum SettingsTab: CaseIterable {
    case alerts, display, calendars, general

    var label: String {
        switch self {
        case .alerts:    "Alerts"
        case .display:   "Display"
        case .calendars: "Calendars"
        case .general:   "General"
        }
    }

    var icon: String {
        switch self {
        case .alerts:    "bell.fill"
        case .display:   "speedometer"
        case .calendars: "calendar"
        case .general:   "gearshape.fill"
        }
    }
}

// MARK: - Tab bar button

private struct TabBarButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(tab.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isSelected ? Color.primary.opacity(0.07) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme picker button

private struct ThemeButton: View {
    let theme: AirplaneTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.accentColor.opacity(0.12))
                        .frame(width: 76, height: 60)
                    Image("airplane")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 50)
                        .hueRotation(.degrees(theme.hueShift))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? theme.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 0.5)
                )
                Text(theme.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.accentColor : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preferences view

struct PreferencesView: View {
    @EnvironmentObject var controller: AppController
    @State private var selectedTab: SettingsTab = .alerts

    private let alertOptions      = [0, 2, 5, 10, 15]
    private let earlyAlertOptions = [0, 10, 15, 20, 30]
    private let snoozeOptions     = [2, 5, 10]

    private var calendarsByAccount: [(account: String, calendars: [CalendarInfo])] {
        let grouped = Dictionary(grouping: controller.availableCalendars, by: \.accountName)
        return grouped.keys.sorted().map { (account: $0, calendars: grouped[$0]!) }
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Tab bar
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    TabBarButton(tab: tab, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            Divider()

            // MARK: Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .alerts:    alertsTab
                    case .display:   displayTab
                    case .calendars: calendarsTab
                    case .general:   generalTab
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // MARK: Footer — calendar status + actions
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    if controller.hasAppleAccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Calendar connected")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Calendar access required")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Button("Grant Access") {
                            controller.requestAppleAccess()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                    Spacer()
                    Button {
                        controller.testAirplane()
                    } label: {
                        Label("Test", systemImage: "airplane")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Divider()
                        .frame(height: 14)

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit", systemImage: "power")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.regularMaterial)
        }
        .frame(minWidth: 420, minHeight: 380)
    }

    // MARK: Tab content builders

    @ViewBuilder private var alertsTab: some View {
        SettingsCard(title: "Alerts") {
            SettingsRow(icon: "person.2.fill", iconColor: .indigo,
                        title: "Skip solo events",
                        subtitle: "Only alert for meetings with others") {
                Toggle("", isOn: $controller.skipSoloEvents)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider().padding(.leading, 56)

            SettingsRow(icon: "bell.fill", iconColor: .blue,
                        title: "Alert me",
                        subtitle: "Before each meeting") {
                Picker("", selection: $controller.alertMinutesBefore) {
                    ForEach(alertOptions, id: \.self) { min in
                        Text(min == 0 ? "On time" : "\(min) min").tag(min)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 100)
            }

            Divider().padding(.leading, 56)

            SettingsRow(icon: "bell.badge.fill", iconColor: .orange,
                        title: "Early warning",
                        subtitle: "Second flyover at a higher lead time") {
                Picker("", selection: $controller.earlyAlertMinutes) {
                    ForEach(earlyAlertOptions, id: \.self) { min in
                        Text(min == 0 ? "Off" : "\(min) min").tag(min)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 100)
            }
        }

        SettingsCard(title: "Snooze") {
            SettingsRow(icon: "moon.zzz.fill", iconColor: .purple,
                        title: "Snooze duration",
                        subtitle: "Tap the airplane to snooze") {
                Picker("", selection: $controller.snoozeMinutes) {
                    ForEach(snoozeOptions, id: \.self) { min in
                        Text("\(min) min").tag(min)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 165)
            }
        }
    }

    @ViewBuilder private var displayTab: some View {
        SettingsCard(title: "Theme") {
            HStack(spacing: 16) {
                ForEach(AirplaneTheme.allCases, id: \.self) { theme in
                    ThemeButton(
                        theme: theme,
                        isSelected: controller.airplaneTheme == theme
                    ) {
                        controller.airplaneTheme = theme
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }

        SettingsCard(title: "Display") {
            SettingsRow(icon: "speedometer", iconColor: .green,
                        title: "Plane speed") {
                Picker("", selection: $controller.flightDuration) {
                    Text("Slow").tag(AppController.slowSpeed)
                    Text("Normal").tag(AppController.normalSpeed)
                    Text("Fast").tag(AppController.fastSpeed)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
            }

            Divider().padding(.leading, 56)

            SettingsRow(icon: "arrow.up.and.down", iconColor: .teal,
                        title: "Screen position",
                        subtitle: "\(Int(controller.screenPositionPercent * 100))% from bottom") {
                Slider(value: $controller.screenPositionPercent, in: 0.1...0.9, step: 0.05)
                    .frame(width: 160)
            }
        }
    }

    @ViewBuilder private var calendarsTab: some View {
        if calendarsByAccount.isEmpty {
            ContentUnavailableView(
                "No Calendars",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Grant calendar access to see your calendars.")
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            ForEach(calendarsByAccount, id: \.account) { group in
                SettingsCard(title: group.account) {
                    ForEach(Array(group.calendars.enumerated()), id: \.element.id) { index, cal in
                        if index > 0 { Divider().padding(.leading, 56) }
                        SettingsRow(icon: "circle.fill",
                                    iconColor: Color(nsColor: cal.color),
                                    title: cal.title) {
                            Toggle("", isOn: Binding(
                                get: { !controller.disabledCalendarIDs.contains(cal.id) },
                                set: { enabled in
                                    if enabled { controller.disabledCalendarIDs.remove(cal.id) }
                                    else       { controller.disabledCalendarIDs.insert(cal.id) }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var generalTab: some View {
        SettingsCard(title: "General") {
            SettingsRow(icon: "speaker.wave.2.fill", iconColor: .pink,
                        title: "Sound",
                        subtitle: "Play Ping when airplane appears") {
                Toggle("", isOn: $controller.playSound)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider().padding(.leading, 56)

            SettingsRow(icon: "power", iconColor: .gray,
                        title: "Launch at login") {
                Toggle("", isOn: $controller.launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }
}
