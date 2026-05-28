import SwiftUI

struct AirplaneView: View {
    let meetingTitle: String
    let minutesUntil: Int
    let flightDuration: Double
    let screenWidth: CGFloat
    var onSnooze: (() -> Void)? = nil

    @State private var xOffset: CGFloat = -650
    @State private var opacity: Double = 1.0
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: -10) {
            Text("\(meetingTitle) in \(minutesUntil) min")
                .font(.custom("Comic Sans MS", size: 28))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 50)
                .padding(.vertical, 22)
                .background(
                    Image("banner")
                        .resizable()
                )

            Image("airplane")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .zIndex(-1)
        }
        .fixedSize()
        .scaleEffect(isHovered && onSnooze != nil ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            guard onSnooze != nil else { return }
            isHovered = hovering
            hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
        }
        .onTapGesture { onSnooze?() }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
        minutesUntil:   5,
        flightDuration: 14,
        screenWidth:    1000
    )
    .frame(width: 1000, height: 110)
    .background(Color.gray.opacity(0.2))
}
