import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var controller: AppController

    private let alertOptions  = [2, 5, 10, 15]
    private let snoozeOptions = [2, 5, 10]

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

            // MARK: Alert lead time
            VStack(alignment: .leading, spacing: 4) {
                Text("Alert me")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("Alert me", selection: $controller.alertMinutesBefore) {
                    ForEach(alertOptions, id: \.self) { min in
                        Text("\(min) min").tag(min)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("before each meeting")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // MARK: Snooze duration
            VStack(alignment: .leading, spacing: 4) {
                Text("Snooze for")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("Snooze for", selection: $controller.snoozeMinutes) {
                    ForEach(snoozeOptions, id: \.self) { min in
                        Text("\(min) min").tag(min)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("tap the airplane to snooze")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // MARK: Plane speed
            VStack(alignment: .leading, spacing: 4) {
                Text("Plane speed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("Plane speed", selection: $controller.flightDuration) {
                    Text("Slow").tag(AppController.slowSpeed)
                    Text("Normal").tag(AppController.normalSpeed)
                    Text("Fast").tag(AppController.fastSpeed)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            Button {
                controller.testAirplane()
            } label: {
                Label("Test airplane", systemImage: "airplane")
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
        .frame(width: 270)
    }
}
