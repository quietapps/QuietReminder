import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var controller: AppController

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // MARK: Calendar status
            if controller.hasAppleAccess {
                Label("Calendar connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    controller.requestAppleAccess()
                } label: {
                    Label("Grant Calendar access", systemImage: "calendar")
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
                                .fill(Color.accentColor.opacity(0.8))
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

            Button {
                controller.openPreferences()
            } label: {
                Label("Preferences…", systemImage: "gearshape")
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Quiet Reminder", systemImage: "power")
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 250)
    }
}
