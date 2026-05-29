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
    var joinURL: URL? = nil
}

struct CalendarInfo: Identifiable {
    let id: String
    let title: String
    let color: NSColor
    let accountName: String
}

protocol CalendarSourceProvider: AnyObject {
    func fetchUpcomingEvents() async throws -> [CalendarEvent]
    func fetchOngoingEvents() async throws -> [CalendarEvent]
    func fetchUpcomingEventsExtended() async throws -> [CalendarEvent]
    func fetchEventsRestOfDay() async throws -> [CalendarEvent]
}

// MARK: - Airplane theme

enum AirplaneTheme: String, CaseIterable {
    case classic, sky, sunset, rocket, ufo, paper, pigeon, dragonfly

    var name: String {
        switch self {
        case .classic:   "Classic"
        case .sky:       "Sky"
        case .dragonfly: "Dragonfly"
        case .sunset:    "Sunset"
        case .pigeon:    "Pigeon"
        case .rocket:    "Rocket"
        case .ufo:       "UFO"
        case .paper:     "Paper"
        }
    }

    // Hue shift applied to the pink artwork to produce the theme colour.
    var hueShift: Double {
        switch self {
        case .classic:   0
        case .sky:       270
        case .dragonfly: 0
        case .sunset:    60
        case .pigeon:    0
        case .rocket:    0
        case .ufo:       0
        case .paper:     0
        }
    }

    // Banner hue shift for airplane-based themes; custom themes use bannerColor instead.
    var bannerHueShift: Double {
        switch self {
        case .classic:   0
        case .sky:       270
        case .dragonfly: 0
        case .sunset:    60
        case .pigeon:    0
        case .rocket:    30
        case .ufo:       150
        case .paper:     230
        }
    }

    // Vehicle image hue shift — 0 for non-airplane themes so they show natural colors.
    var vehicleHueShift: Double {
        switch self {
        case .classic:   0
        case .sky:       270
        case .dragonfly: 0
        case .sunset:    60
        case .pigeon:    0
        case .rocket:    0
        case .ufo:       0
        case .paper:     0
        }
    }

    /// When non-nil, the banner Image is tinted with this color instead of using hueRotation.
    var bannerTintColor: NSColor? {
        switch self {
        case .pigeon:    return NSColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1) // off-white
        case .dragonfly: return NSColor(red: 0.13, green: 0.47, blue: 0.18, alpha: 1) // dark green
        default:         return nil
        }
    }

    /// Text color on the banner — dark for light-background themes, white otherwise.
    var bannerTextColor: Color {
        switch self {
        case .paper: return Color(white: 0.15)
        default:              return .white
        }
    }

    var accentColor: Color {
        switch self {
        case .classic:   .pink
        case .sky:       .blue
        case .dragonfly: .green
        case .sunset:    .orange
        case .pigeon:    Color(white: 0.55)
        case .rocket:    .orange
        case .ufo:       .green
        case .paper:     .cyan
        }
    }

    var vehicleImageName: String {
        switch self {
        case .classic, .sky, .sunset: "airplane"
        case .dragonfly: "dragonfly"
        case .pigeon:    "pigeon"
        case .rocket:    "rocket"
        case .ufo:       "ufo"
        case .paper:     "paper"
        }
    }
}
