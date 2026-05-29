import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var controller: AppController

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private var endOfToday: Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400 - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // MARK: Pause banner
            if controller.isPaused {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(.orange)
                        Text(controller.pauseStatusText ?? "Paused")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    HStack {
                        Text("No flyovers until resumed")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Resume") { controller.resume() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Divider()
            }

            // MARK: Calendar status
            if controller.hasAppleAccess {
                Label("Calendar connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    controller.requestAppleAccess()
                } label: {
                    Label("Enable Calendar Access", systemImage: "calendar")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Speed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("Speed", selection: $controller.flightDuration) {
                    Text("Slow").tag(AppController.slowSpeed)
                    Text("Normal").tag(AppController.normalSpeed)
                    Text("Fast").tag(AppController.fastSpeed)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if controller.showUpcomingEvents && !controller.upcomingEvents.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("TODAY")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(controller.upcomingEvents) { event in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(controller.showCalendarColors
                                      ? (event.calendarColor.map { Color(nsColor: $0) } ?? Color.accentColor).opacity(0.9)
                                      : Color.accentColor.opacity(0.8))
                                .frame(width: 6, height: 6)
                            Text(event.title)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            Text(timeString(event.startDate))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            Button {
                controller.testAirplane()
            } label: {
                Label("Test airplane", systemImage: "airplane")
            }
            .buttonStyle(.plain)
            .pointingHandCursor()

            if controller.isPaused {
                Button { controller.resume() } label: {
                    Label("Resume notifications", systemImage: "play.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
                .pointingHandCursor()
            } else {
                Menu {
                    Button("Indefinitely") { controller.pause(until: .distantFuture) }
                    Button("Today")        { controller.pause(until: endOfToday) }
                    Divider()
                    Button("5 minutes")  { controller.pause(until: Date().addingTimeInterval(5  * 60)) }
                    Button("10 minutes") { controller.pause(until: Date().addingTimeInterval(10 * 60)) }
                    Button("15 minutes") { controller.pause(until: Date().addingTimeInterval(15 * 60)) }
                    Button("30 minutes") { controller.pause(until: Date().addingTimeInterval(30 * 60)) }
                    Button("1 hour")     { controller.pause(until: Date().addingTimeInterval(3600)) }
                } label: {
                    Label("Pause notifications", systemImage: "pause.circle")
                        .foregroundStyle(.primary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .pointingHandCursor()
            }

            Button {
                controller.openPreferences()
            } label: {
                Label("Preferences…", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .pointingHandCursor()

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Quiet Reminder", systemImage: "power")
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .padding(14)
        .frame(width: 250)
    }
}
