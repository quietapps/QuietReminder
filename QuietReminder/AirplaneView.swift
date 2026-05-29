import Combine
import SwiftUI

// 60 Hz timer-driven position so animation can be paused on hover.
@MainActor
final class AirplaneAnimController: ObservableObject {
    @Published var xOffset: CGFloat = -600
    @Published var opacity: Double  = 1.0
    var isPaused = false

    private let endX: CGFloat
    private let flightDuration: TimeInterval
    private var elapsed: TimeInterval = 0
    private var timer: Timer?

    init(screenWidth: CGFloat, flightDuration: TimeInterval) {
        self.endX = screenWidth + 600
        self.flightDuration = flightDuration
    }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !isPaused else { return }
        elapsed += 1.0 / 60.0
        let progress = min(elapsed / flightDuration, 1.0)
        xOffset = -600 + (endX + 600) * CGFloat(progress)

        let fadeStart = flightDuration - 0.6
        if elapsed > fadeStart {
            opacity = max(0, 1.0 - (elapsed - fadeStart) / 0.6)
        }
        if elapsed >= flightDuration { stop() }
    }
}

// NSButton wrapper — reliably handles clicks in non-key NSPanel.
private struct ActionButton: NSViewRepresentable {
    let title: String
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let btn = NSButton(title: "",
                           target: context.coordinator,
                           action: #selector(Coordinator.fire))
        btn.bezelStyle = .rounded
        btn.isBordered = true
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 10
        btn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
        btn.attributedTitle = Self.styled(title)
        return btn
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.attributedTitle = Self.styled(title)
    }

    private static func styled(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .foregroundColor: NSColor.black,
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
        ])
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func fire() { action() }
    }
}

// Transparent NSButton overlay — makes the airplane image clickable while
// preserving the SwiftUI Image rendering (including hueRotation from parent).
private struct TransparentButton: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let btn = NSButton(title: "",
                           target: context.coordinator,
                           action: #selector(Coordinator.fire))
        btn.isBordered = false
        btn.bezelStyle = .shadowlessSquare
        btn.imagePosition = .noImage
        btn.wantsLayer = true
        btn.layer?.backgroundColor = CGColor.clear
        return btn
    }

    func updateNSView(_ nsView: NSButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func fire() { action() }
    }
}

struct AirplaneView: View {
    let meetingTitle: String
    let participants: String?
    let minutesUntil: Int
    let flightDuration: Double
    var theme: AirplaneTheme = .classic
    let screenWidth: CGFloat
    var onSnooze: (() -> Void)? = nil
    var snoozeLabel: String? = nil
    var onJoin: (() -> Void)? = nil

    @ObservedObject private var anim: AirplaneAnimController
    @State private var isHovered = false

    init(meetingTitle: String,
         participants: String?,
         minutesUntil: Int,
         flightDuration: Double,
         theme: AirplaneTheme = .classic,
         screenWidth: CGFloat,
         animController: AirplaneAnimController,
         onSnooze: (() -> Void)? = nil,
         snoozeLabel: String? = nil,
         onJoin: (() -> Void)? = nil) {
        self.meetingTitle   = meetingTitle
        self.participants   = participants
        self.minutesUntil   = minutesUntil
        self.flightDuration = flightDuration
        self.theme          = theme
        self.screenWidth    = screenWidth
        self.anim           = animController
        self.onSnooze       = onSnooze
        self.snoozeLabel    = snoozeLabel
        self.onJoin         = onJoin
    }

    private var timeLabel: String {
        if minutesUntil > 0 { return "in \(minutesUntil) min" }
        if minutesUntil == 0 { return "NOW" }
        return "ends in \(-minutesUntil) min"
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: -10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(meetingTitle) \(timeLabel)")
                        .font(.custom("Comic Sans MS", size: 26))
                        .foregroundStyle(theme.bannerTextColor)
                        .lineLimit(1)
                    if let p = participants {
                        Text(p)
                            .font(.custom("Comic Sans MS", size: 15))
                            .foregroundStyle(theme.bannerTextColor.opacity(0.75))
                            .lineLimit(1)
                    }
                    if isHovered, snoozeLabel != nil || onJoin != nil {
                        HStack(spacing: 8) {
                            if let label = snoozeLabel {
                                ActionButton(title: label, action: { onSnooze?() })
                                    .frame(height: 26)
                            }
                            if let join = onJoin {
                                ActionButton(title: "Join ↗", action: join)
                                    .frame(height: 26)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 50)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if let tint = theme.bannerTintColor {
                            Image("banner").resizable()
                                .saturation(0)
                                .colorMultiply(Color(nsColor: tint))
                        } else {
                            Image("banner").resizable()
                                .hueRotation(.degrees(theme.bannerHueShift))
                        }
                    }
                )
                .fixedSize()

                // Airplane image; transparent NSButton overlay captures clicks when
                // a join URL is available (hitTest only returns NSButton hits).
                ZStack {
                    Image(theme.vehicleImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 180)
                        .hueRotation(.degrees(theme.vehicleHueShift))
                    if let join = onJoin {
                        TransparentButton(action: join)
                    }
                }
                .frame(height: 180)
                .zIndex(-1)
            }
        }
        .fixedSize()
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) { isHovered = hovering }
            anim.isPaused = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .position(x: anim.xOffset, y: 60)
        .opacity(anim.opacity)
        .onAppear  { anim.start() }
        .onDisappear {
            anim.stop()
            if isHovered { NSCursor.pop() }
        }
    }
}

#Preview {
    AirplaneView(
        meetingTitle:   "Weekly Standup",
        participants:   "with John, Jane +2 more",
        minutesUntil:   5,
        flightDuration: 14,
        screenWidth:    1000,
        animController: AirplaneAnimController(screenWidth: 1000, flightDuration: 14),
        snoozeLabel:    "Snooze 5 min",
        onJoin:         { NSWorkspace.shared.open(URL(string: "https://google.com")!) }
    )
    .frame(width: 1000, height: 120)
    .background(Color.gray.opacity(0.2))
}
