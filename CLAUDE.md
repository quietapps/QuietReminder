# CLAUDE.md — Quiet Reminder

Context for AI assistants working in this repo.

## Project

Quiet Reminder — native macOS menu bar app that flies a hand-drawn airplane across the screen trailing a meeting-title banner, ~5 minutes before each calendar event. Swift 5.9 + SwiftUI + AppKit. Min deployment macOS 26.0. Bundle ID `app.quiet.QuietReminder`. MIT licensed.

## Build & run

The Xcode project is committed directly (no XcodeGen). Open and run:

```bash
open QuietReminder.xcodeproj
# Press ⌘R in Xcode
```

Or from the command line:

```bash
# Build Debug
xcodebuild -project QuietReminder.xcodeproj -scheme QuietReminder -configuration Debug -destination 'platform=macOS' build

# Build Release
xcodebuild -project QuietReminder.xcodeproj -scheme QuietReminder -configuration Release -destination 'platform=macOS' build

# Clean
xcodebuild -project QuietReminder.xcodeproj -scheme QuietReminder clean
```

Built `.app` lands in `~/Library/Developer/Xcode/DerivedData/QuietReminder-*/Build/Products/{Debug,Release}/QuietReminder.app`.

No test target. No linter configured.

## Bumping the version

Version is set directly in `QuietReminder.xcodeproj/project.pbxproj` (both Debug and Release build config blocks):

- `MARKETING_VERSION` — e.g. `1.0`
- `CURRENT_PROJECT_VERSION` — e.g. `1`

Edit both occurrences (Debug + Release) by hand, then update `CHANGELOG.md`.

## App icon standard (macOS 26 Tahoe)

All Quiet Apps icons must follow this spec or they appear oversized in the Dock:

- **Canvas:** 1024×1024 px transparent PNG
- **Outer padding:** 9% transparent on all sides → artwork in center 82%. Outer ring fully transparent.
- **Squircle shape:** true superellipse (n=5), NOT `CGPath(roundedRect:)`. Corner radius ≈ 22% of art area width (~188px on an 840×840 art area).
- **Background fill:** fills the squircle only — never the full 1024px canvas.

Reference superellipse implementation: `QuietFinance/scripts/GenerateIcon.swift` → `squirclePath(in:exponent:)` with `exponent: 5.0` and `pad: 0.09`.

## Architecture

Four classes wired together by `AppController`. No singletons beyond `AppController` (owned by `@StateObject` in `QuietReminderApp`).

### `QuietReminderApp` (entry point)

`@main` SwiftUI `App`. Creates one `AppController` as `@StateObject` and passes it into `MenuBarExtra` via `.environmentObject`. `MenuBarExtraStyle` is `.window` (popover-style panel, not a menu).

### `AppController`

`@MainActor ObservableObject`. Central coordinator. Owns:
- `AppleCalendarService` (EventKit wrapper)
- `CalendarPoller` (started once access is granted, stopped/replaced on access change)
- `[AirplaneOverlayWindow]` — live overlay windows (retained for animation lifetime, then released)

Published state:
- `hasAppleAccess: Bool` — drives the Grant/Connected UI in `MenuBarView`
- `flightDuration: Double` — persisted to `UserDefaults.standard["flightDuration"]`; three static presets: `slowSpeed = 22`, `normalSpeed = 14`, `fastSpeed = 8` (seconds)

Key methods:
- `requestAppleAccess()` — async EventKit prompt, updates `hasAppleAccess`, starts polling
- `testAirplane()` — fires a fake `CalendarEvent` immediately (useful for layout/speed testing)
- `showAirplane(for:minutesUntil:)` — creates `AirplaneOverlayWindow`, appends to array, schedules removal at `flightDuration + 1.5s`

### `CalendarPoller`

`@MainActor` class. 60-second `Timer` that calls `service.fetchUpcomingEvents()` each tick. Alert fires when `minutesUntil ∈ [alertMinutesBefore-1, alertMinutesBefore+1]` (default window: 4–6 minutes). `notifiedIDs: Set<String>` prevents double-firing for the same event across poll cycles. Callback: `onMeetingSoon: ((CalendarEvent, Int) -> Void)?`.

To change lead time: edit `static let alertMinutesBefore = 5` in `CalendarPoller.swift`.

### `CalendarSourceProvider` / `AppleCalendarService`

`CalendarSourceProvider` is a protocol (`fetchUpcomingEvents() async throws -> [CalendarEvent]`) — makes the poller testable with a mock.

`AppleCalendarService` wraps `EKEventStore`:
- `hasAccess` — checks `EKEventStore.authorizationStatus(for: .event) == .fullAccess`
- `requestAccess()` — calls `store.requestFullAccessToEvents()`
- `fetchUpcomingEvents()` — predicate covers `now...now+1h`, all calendars. Banner title logic: if event has attendees besides the current user, formats "Meeting with Name" / "Meeting with A and B" / "Meeting with A, B +N more"; otherwise falls back to `event.title`.

### `AirplaneView`

SwiftUI `View`. Horizontal `HStack` of a text+banner layer and an airplane `Image`. Animation: `xOffset` starts at `-650` (off-left), animates linearly to `screenWidth + 50` (off-right) over `flightDuration` seconds. Fade-out starts `flightDuration - 0.6s` in, over 0.6s. Font: Comic Sans MS 28pt white. Banner image resizable behind text with `padding(.horizontal, 50)` / `padding(.vertical, 22)`.

### `AirplaneOverlayWindow`

`NSPanel` subclass. Window level: `CGWindowLevelForKey(.maximumWindow) + 1` — above fullscreen apps. Positioned at 65% of screen height (`sf.minY + sf.height * 0.65`), full screen width, 110pt tall. Properties: `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false`, `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`. `canBecomeKey` and `canBecomeMain` both return `false`.

Content is an `NSHostingView<AirplaneView>` with a clear layer background.

## Assets

All in `QuietReminder/Assets.xcassets/`:

| Imageset | Purpose |
|---|---|
| `airplane` | Right-facing hand-drawn pink airplane PNG |
| `banner` | Pink banner background (resizable, stretches behind text) |
| `AppIcon` | Dock + Finder icon (follow Quiet Apps icon standard above) |
| `menubar` | Menu bar silhouette — template image, monochrome on transparent |

## Permissions

**Calendar (EventKit)** — only permission the app requests. Privacy strings in `project.pbxproj`:
- `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription`
- `INFOPLIST_KEY_NSCalendarsUsageDescription`

No Accessibility, no sandbox (`ENABLE_APP_SANDBOX = NO`), no network entitlements.

## Reset state during development

```bash
defaults delete app.quiet.QuietReminder
```

## Commit conventions

- Never include `Co-Authored-By: Claude` or any AI authorship trailer in commit messages.
- Do NOT auto-commit or auto-push after making changes. Wait for explicit user instruction to commit.
