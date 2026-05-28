import AppKit
import SwiftUI

// Passes mouse events through to windows behind it, except where SwiftUI
// has an interactive subview (e.g. the tap-to-snooze gesture on the airplane).
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        // nil → click passes through to the window beneath.
        // When the hit is the hosting view itself (background, no gesture owner)
        // we return nil. When it's a specific SwiftUI subview that owns a gesture,
        // we return it so the gesture fires normally.
        return hit == self ? nil : hit
    }
}

// Transparent panel that floats above every window (including fullscreen apps).
final class AirplaneOverlayWindow: NSPanel {

    init(screen: NSScreen,
         meetingTitle: String,
         participants: String?,
         minutesUntil: Int,
         flightDuration: Double,
         theme: AirplaneTheme = .classic,
         yPositionPercent: Double = 0.65,
         onSnooze: (() -> Void)? = nil) {

        let sf = screen.frame
        let height: CGFloat = 120
        let yPos = sf.minY + sf.height * yPositionPercent - height / 2

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
        self.ignoresMouseEvents   = false   // passthrough handled by hitTest override
        self.collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false

        let rootView = AirplaneView(
            meetingTitle:   meetingTitle,
            participants:   participants,
            minutesUntil:   minutesUntil,
            flightDuration: flightDuration,
            theme:          theme,
            screenWidth:    sf.width,
            onSnooze:       onSnooze
        )
        let hostingView = PassthroughHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: sf.width, height: height)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        self.contentView = hostingView
    }

    override var canBecomeKey:  Bool { false }
    override var canBecomeMain: Bool { false }
}
