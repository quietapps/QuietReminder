<div align="center">

<img src="QuietReminder/Assets.xcassets/AppIcon.appiconset/icon_1024.png" alt="Quiet Reminder" width="128" height="128" />

# Quiet Reminder

**A pink airplane flies across your screen before every meeting.**

A native macOS menu bar app that sends a hand-drawn airplane trailing a banner across your screen five minutes before each calendar event — so you never miss a meeting. Part of the [Quiet Apps](https://github.com/quietapps) family.

[![macOS](https://img.shields.io/badge/macOS-26.0+-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-AppKit-2396F3?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[Features](#features) · [Usage](#usage) · [Build from source](#build-from-source) · [FAQ](#faq)

<p>
  <img src="media/demo.gif" alt="Demo" />
</p>

</div>

---

## Why

You're heads-down in code, a doc, a design — and the standup starts in three minutes. Quiet Reminder sends a hand-drawn pink airplane gliding across your screen, trailing a banner with the meeting title, five minutes before every event on your calendar. No notification badge to dismiss, no menu bar to check. You literally cannot miss it.

Works with any calendar you've connected to Calendar.app — iCloud, Google, Exchange, or all three at once.

## Features

- **Flying banner** — borderless transparent panel at screen-saver level; floats above every window including fullscreen apps
- **Reads all your calendars** — EventKit reads directly from Calendar.app; any account (iCloud, Google, Exchange) connected there is automatically included
- **Configurable lead time** — defaults to 5 minutes before each event
- **Speed picker** — Slow / Normal / Fast flight across the screen
- **Test mode** — trigger the animation on demand with a fake event to preview the visuals
- **Menu bar agent** — no Dock icon, just the ✈️ in the menu bar
- **Polling** — checks your calendar every 60 seconds; an in-memory set prevents the same event from triggering twice

## Usage

| Action | How |
|---|---|
| Grant calendar access | Click ✈️ in menu bar → **Grant Calendar access** → Allow |
| Test the animation | Click ✈️ → **Test airplane** |
| Change flight speed | Click ✈️ → Slow / Normal / Fast |
| Quit | Click ✈️ → **Quit Quiet Reminder** |

The airplane appears automatically ~5 minutes before each upcoming event. No further interaction needed once Calendar access is granted.

## Permissions

Quiet Reminder needs **Calendar** access to read upcoming events.

On first launch click **Grant Calendar access** in the menu — macOS shows its standard privacy prompt. The app polls every 60 seconds and starts alerting as soon as access is granted, no restart required.

## Adding your Google Calendar

Quiet Reminder reads from Calendar.app via Apple's EventKit framework. No separate Google integration needed:

1. **System Settings → Internet Accounts → Add Account → Google**
2. Sign in and allow access; make sure **Calendars** is toggled on
3. Open **Calendar.app** and confirm your Google events appear
4. Click **Test airplane** in the Quiet Reminder menu to confirm

No API keys, no OAuth client setup, no developer console.

## Build from source

### Requirements

- macOS 26.0 or later
- Xcode 26.0 or later
- Calendar.app with at least one calendar configured

No paid Apple Developer account required — the project uses ad-hoc signing (`Sign to Run Locally`).

### Steps

```bash
git clone https://github.com/quietapps/QuietReminder.git
cd QuietReminder
open QuietReminder.xcodeproj
```

Press **⌘R** in Xcode. The ✈️ appears in your menu bar.

Or from the command line:

```bash
xcodebuild -project QuietReminder.xcodeproj -scheme QuietReminder -configuration Release build
```

### Project layout

```
QuietReminder/
├── QuietReminderApp.swift       # @main + MenuBarExtra
├── AppController.swift          # Coordinator: EventKit + poller + overlay
├── MenuBarView.swift            # Status / Grant access / Speed / Test / Quit
├── CalendarSource.swift         # CalendarEvent + provider protocol
├── AppleCalendarService.swift   # EventKit implementation
├── CalendarPoller.swift         # 60s timer, fires onMeetingSoon
├── AirplaneView.swift           # SwiftUI airplane + banner animation
├── AirplaneOverlayWindow.swift  # Transparent NSPanel above everything
├── QuietReminder.entitlements   # Sandbox disabled
└── Assets.xcassets/             # Airplane, banner, app icon, menu bar icon
```

No external dependencies — Apple frameworks only (SwiftUI, AppKit, EventKit).

## Customization

### Visuals — `QuietReminder/AirplaneView.swift`

| What | Where |
|---|---|
| Flight duration (slower/faster) | `flightDuration` |
| Plane size | `Image("airplane")` → `frame(width:height:)` |
| Banner padding | `padding(.horizontal:)` / `padding(.vertical:)` |
| Font / text size / color | `font(...)`, `foregroundStyle(...)` |
| Vertical screen position | `AirplaneOverlayWindow.swift` → `yPos` |

### Alert timing — `QuietReminder/CalendarPoller.swift`

```swift
static let alertMinutesBefore = 5   // change to alert at a different lead time
```

### Artwork

Replace assets in `QuietReminder/Assets.xcassets/`:

- `airplane.imageset/` — flying airplane (right-facing)
- `banner.imageset/` — pink banner background
- `AppIcon.appiconset/` — Dock + Finder icon
- `menubar.imageset/` — menu bar silhouette (template image, monochrome on transparent)

## Configuration

Settings live in `UserDefaults`. Reset with:

```bash
defaults delete app.quiet.QuietReminder
```

## FAQ

**Does it work with Google Calendar?**
Yes — connect Google to Calendar.app via System Settings → Internet Accounts and Quiet Reminder picks it up automatically via EventKit. No separate setup needed.

**Can I change the alert time (earlier or later than 5 minutes)?**
Edit `static let alertMinutesBefore` in `CalendarPoller.swift` and rebuild.

**The airplane doesn't appear before my meeting.**
Make sure Calendar access is granted (✈️ menu shows a green checkmark). If the app was running before you granted access, click **Test airplane** to confirm the animation works, then wait for the next event.

**Can I use it with multiple calendars?**
Yes — EventKit reads every calendar configured in Calendar.app, across all connected accounts.

**Can I make it appear earlier than 5 minutes?**
Edit `alertMinutesBefore` in `CalendarPoller.swift`.

**How do I quit?**
Click ✈️ in the menu bar → **Quit Quiet Reminder**.

## License

[MIT](LICENSE) © Quiet Apps

---

<div align="center">
If Quiet Reminder keeps you on time, drop a ⭐ on the repo.
</div>
