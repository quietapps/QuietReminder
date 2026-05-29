import AppKit
import SwiftUI

// Passes clicks through to apps behind UNLESS the click lands on an NSButton
// (the snooze button). Hover events bypass hitTest entirely — they go to the
// NSTrackingArea owner — so .onHover keeps working with this override.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        var v: NSView? = hit
        while let view = v {
            if view is NSButton { return hit }
            v = view.superview
        }
        return nil
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
         animController: AirplaneAnimController,
         onSnooze: (() -> Void)? = nil,
         snoozeLabel: String? = nil,
         onJoin: (() -> Void)? = nil) {

        let sf     = screen.frame
        let height: CGFloat = 120
        let yPos   = sf.minY + sf.height * yPositionPercent - height / 2

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
        self.ignoresMouseEvents   = false
        self.collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false

        let rootView = AirplaneView(
            meetingTitle:   meetingTitle,
            participants:   participants,
            minutesUntil:   minutesUntil,
            flightDuration: flightDuration,
            theme:          theme,
            screenWidth:    sf.width,
            animController: animController,
            onSnooze:       onSnooze,
            snoozeLabel:    snoozeLabel,
            onJoin:         onJoin
        )
        let hostingView = PassthroughHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: sf.width, height: height)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        self.contentView = hostingView
    }

    override var canBecomeKey:  Bool { false }
    override var canBecomeMain: Bool { false }
    override func makeKey() {}
}
