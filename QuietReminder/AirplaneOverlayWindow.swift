import AppKit
import Combine
import SwiftUI

// Passes clicks through to apps behind UNLESS the click lands on an NSButton.
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

// One push is live at most. Prevents stack corruption when multiple windows
// transition hover state in the same run-loop turn.
private var currentHoveredAnim: AirplaneAnimController? = nil

@MainActor func clearHover(for anim: AirplaneAnimController) {
    if currentHoveredAnim === anim {
        currentHoveredAnim = nil
        NSCursor.pop()
    }
    anim.isHovered = false
    anim.isPaused  = false
}

// Full-screen-width transparent panel so macOS clips the animation content
// exactly at each screen's edges (correct multi-screen entry/exit).
//
// Hover is NOT driven by NSTrackingArea — only the topmost overlapping window
// receives tracking events, breaking lower windows. Instead:
//
//  • ignoresMouseEvents starts true (never blocks other apps or lower banners)
//  • A 60 Hz cursor-position check (piggybacking the animation tick via Combine)
//    detects when the cursor enters this airplane's content region
//  • On hover-enter: ignoresMouseEvents = false so button clicks are receivable
//  • On hover-exit: ignoresMouseEvents = true again
//
// This way every concurrent banner is independently hoverable regardless of
// z-order, and the horizontal strip never steals clicks from other apps.
final class AirplaneOverlayWindow: NSPanel {

    private var xCancellable: AnyCancellable?
    private var mouseMonitor: Any?

    deinit {
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
    }

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

        self.level              = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        self.backgroundColor    = .clear
        self.isOpaque           = false
        self.hasShadow          = false
        self.ignoresMouseEvents = true   // default off; toggled on hover only
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
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
        hostingView.layer?.backgroundColor = CGColor.clear
        self.contentView = hostingView

        let screenMinX = sf.minX
        let frameMinY  = yPos
        let frameMaxY  = yPos + height

        // Runs every animation tick (60 Hz) to check cursor position.
        // Handles the common case: airplane flies under a stationary cursor.
        xCancellable = animController.$xOffset
            .receive(on: RunLoop.main)
            .sink { [weak self, weak animController] x in
                guard let self, let anim = animController else { return }
                self.checkHover(anim: anim, x: x,
                                screenMinX: screenMinX,
                                frameMinY: frameMinY, frameMaxY: frameMaxY)
            }

        // Catches the reverse case: cursor moves to a stationary/paused airplane.
        // Because ignoresMouseEvents is true by default, the event reaches our app
        // only when the hovered window (ignoresMouseEvents = false) gets it — that
        // window's monitor fires, and ALL local monitors run for every app event.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .mouseEntered, .mouseExited]
        ) { [weak self, weak animController] event in
            guard let self, let anim = animController else { return event }
            self.checkHover(anim: anim, x: anim.xOffset,
                            screenMinX: screenMinX,
                            frameMinY: frameMinY, frameMaxY: frameMaxY)
            return event
        }
    }

    private func checkHover(anim: AirplaneAnimController, x: CGFloat,
                            screenMinX: CGFloat,
                            frameMinY: CGFloat, frameMaxY: CGFloat) {
        let cursor  = NSEvent.mouseLocation
        let inVert  = cursor.y >= frameMinY && cursor.y <= frameMaxY
        let centerX = screenMinX + x
        // ±450 pt covers the full banner + airplane group for typical titles.
        let inHoriz = cursor.x >= centerX - 450 && cursor.x <= centerX + 450
        let over    = inVert && inHoriz

        MainActor.assumeIsolated {
            if over {
                if currentHoveredAnim == nil { NSCursor.pointingHand.push() }
                currentHoveredAnim    = anim
                anim.isHovered        = true
                anim.isPaused         = true
                ignoresMouseEvents    = false   // accept clicks for snooze/join buttons
            } else if currentHoveredAnim === anim {
                currentHoveredAnim    = nil
                anim.isHovered        = false
                anim.isPaused         = false
                ignoresMouseEvents    = true
                NSCursor.pop()
            } else {
                anim.isHovered        = false
                anim.isPaused         = false
                ignoresMouseEvents    = true
            }
        }
    }

    override var canBecomeKey:  Bool { false }
    override var canBecomeMain: Bool { false }
    override func makeKey() {}
}
