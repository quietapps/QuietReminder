import SwiftUI

struct AirplaneView: View {
    let meetingTitle: String
    let participants: String?
    let minutesUntil: Int
    let flightDuration: Double
    var theme: AirplaneTheme = .classic
    let screenWidth: CGFloat
    var onSnooze: (() -> Void)? = nil

    @State private var xOffset: CGFloat = -650
    @State private var opacity: Double = 1.0
    @State private var isHovered = false

    private var timeLabel: String {
        minutesUntil == 0 ? "NOW" : "in \(minutesUntil) min"
    }

    var body: some View {
        HStack(spacing: -10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(meetingTitle) \(timeLabel)")
                    .font(.custom("Comic Sans MS", size: 26))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let p = participants {
                    Text(p)
                        .font(.custom("Comic Sans MS", size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 50)
            .padding(.vertical, 16)
            .background(Image("banner").resizable())
            .fixedSize()

            Image("airplane")
                .resizable()
                .scaledToFit()
                .frame(height: 180)
                .zIndex(-1)
        }
        .hueRotation(.degrees(theme.hueShift))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .scaleEffect(isHovered && onSnooze != nil ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            guard onSnooze != nil else { return }
            isHovered = hovering
            hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
        }
        .onTapGesture { onSnooze?() }
        .offset(x: xOffset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.linear(duration: flightDuration)) {
                xOffset = screenWidth + 50
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + flightDuration - 0.6) {
                withAnimation(.easeIn(duration: 0.6)) {
                    opacity = 0
                }
            }
        }
    }
}

#Preview {
    AirplaneView(
        meetingTitle:   "Weekly Standup",
        participants:   "with John, Jane +2 more",
        minutesUntil:   5,
        flightDuration: 14,
        screenWidth:    1000
    )
    .frame(width: 1000, height: 120)
    .background(Color.gray.opacity(0.2))
}
