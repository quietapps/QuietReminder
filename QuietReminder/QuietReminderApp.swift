import SwiftUI

@main
struct QuietReminderApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        // Lives in the menu bar only — no Dock icon needed (set LSUIElement in Info.plist)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(controller)
        } label: {
            HStack(spacing: 3) {
                Image("menubar")
                    .renderingMode(.template)
                if let txt = controller.menuBarCountdownText {
                    Text(txt)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(.white)
        }
        .menuBarExtraStyle(.window)
    }
}
