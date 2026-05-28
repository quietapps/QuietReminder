import Foundation
import AppKit
import SwiftUI

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let hasOtherAttendees: Bool
    let participants: String?
}

struct CalendarInfo: Identifiable {
    let id: String
    let title: String
    let color: NSColor
    let accountName: String
}

protocol CalendarSourceProvider: AnyObject {
    func fetchUpcomingEvents() async throws -> [CalendarEvent]
}

// MARK: - Airplane theme

enum AirplaneTheme: String, CaseIterable {
    case classic, sky, forest, sunset, lavender

    var name: String {
        switch self {
        case .classic:  "Classic"
        case .sky:      "Sky"
        case .forest:   "Forest"
        case .sunset:   "Sunset"
        case .lavender: "Lavender"
        }
    }

    // Hue shift applied to the pink artwork to produce the theme colour.
    // Pink ≈ 330°. Adding these shifts gives: pink, blue, green, orange, purple.
    var hueShift: Double {
        switch self {
        case .classic:  0
        case .sky:      270
        case .forest:   150
        case .sunset:   60
        case .lavender: 300
        }
    }

    var accentColor: Color {
        switch self {
        case .classic:  .pink
        case .sky:      .blue
        case .forest:   .green
        case .sunset:   .orange
        case .lavender: .purple
        }
    }
}
