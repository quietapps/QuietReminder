import AppKit
import SwiftUI

// Transparent panel that floats above every window (including fullscreen apps).
// Clickable when onSnooze is provided — clicking anywhere on the panel snoozes the event.
final class AirplaneOverlayWindow: NSPanel {

    init(screen: NSScreen, meetingTitle: String, minutesUntil: Int, flightDuration: Double, onSnooze: (() -> Void)? = nil) {
        let sf = screen.frame
        let height: CGFloat = 110
        let yPos = sf.minY + sf.height * 0.65

        super.init(
            contentRect: NSRect(x: sf.minX, y: yPos, width: sf.width, height: height),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )

        self.level                = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        self.backgroundColor      = .clear
        self.isOpaque             = false
        self.hasShadow            = false
        self.ignoresMouseEvents   = (onSnooze == nil)
        self.collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false

        let rootView = AirplaneView(
            meetingTitle:   meetingTitle,
            minutesUntil:   minutesUntil,
            flightDuration: flightDuration,
            screenWidth:    sf.width,
            onSnooze:       onSnooze
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: sf.width, height: height)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        self.contentView = hostingView
    }

    override var canBecomeKey:  Bool { false }
    override var canBecomeMain: Bool { false }
}
