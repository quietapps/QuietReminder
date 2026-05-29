# Changelog

All notable changes to **Quiet Reminder** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4] — 2026-05-29

**Build 5** · Pause mode, calendar-color theming, display polish, and menu bar improvements.

### Added

- **Pause notifications** — new "Pause notifications" menu in the menu bar popover lets you suppress all flyovers for: 5, 10, 15, or 30 minutes; 1 hour; the rest of today; or indefinitely. Auto-resumes when the duration expires. While paused, the menu bar shows a pause icon instead of the countdown, and an orange status banner in the popover shows remaining time with a "Resume" button.
- **Calendar-color banner** — new toggle in Display → Banner: when on, the airplane banner is tinted to match the calendar color of the event (desaturates the banner image and multiplies by the calendar color). Text color adjusts automatically via luminance — dark text on light calendars, white text on dark ones.
- **Calendar color dots** — upcoming events list in the menu bar popover now shows colored dots matching each event's calendar color. Toggle in General → Upcoming events. On by default.
- **Custom alert sound** — sound picker replaces the plain on/off toggle. Choose from all 14 macOS system sounds (Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink). Previews the selected sound immediately on change.
- **Banner opacity** — new slider in Display (30–100%) controls the transparency of the banner. The airplane vehicle stays fully opaque.
- **Event title in menu bar** — new toggle in General: when "Menu bar countdown" and "Show event title" are both on, the menu bar label appends the meeting name to the countdown (e.g. `in 4m · Standup`, truncated at 20 characters).
- **Active Screen** — new option in Display → Screens. When selected, the banner appears on whichever screen the cursor is on at the time the alert fires. Falls back to the main screen if the cursor position can't be resolved.

### Changed

- **Screen selector** — "Active Screen" option added at the top of the per-screen list when "Show on all screens" is off; per-screen rows now have dividers between them.

---

## [1.3] — 2026-05-29

**Build 2** · Menu bar icon refresh and smarter meeting join-link detection.

### Added

- **SafeLinks support** — join URLs wrapped by Microsoft SafeLinks (`safelinks.protection.outlook.com`) are now decoded; the inner meeting URL is extracted and used directly rather than linking to the wrapper.
- **Mimecast support** — join URLs wrapped by Mimecast (`mimecastprotect.com`) are detected; inner URL decoded if available, otherwise the Mimecast redirect URL is used so the browser follows through to the meeting.
- **Angle-bracket URL parsing** — Outlook and Teams invite bodies often format links as `<https://…>`; the extractor now strips the brackets and validates the inner URL.
- **`event.location` scan** — join-link search now also checks the event location field, which some calendar systems populate with the meeting URL.

### Changed

- **Menu bar icon** — updated to a cleaner outlined airplane silhouette; regenerated as a black-on-transparent template image at 1×/2×/3× (22/44/66 px) so macOS auto-tints for light and dark menu bars.
- **`event.url` unwrapping** — if the ICS `URL:` field itself contains a SafeLinks or Mimecast wrapper, it is now decoded before use rather than returned verbatim.
- **Hover detection rewrite** — replaced `NSTrackingArea`-based hover (only the topmost overlapping window receives tracking events, breaking lower banners) with a 60 Hz cursor-position check driven by the existing Combine animation tick plus a local mouse-event monitor. `ignoresMouseEvents` starts `true` (never blocks other apps) and is toggled `false` only when the cursor enters the airplane's content region, so every concurrent banner is independently hoverable regardless of z-order. `isHovered` moved from view `@State` into `AirplaneAnimController` so the overlay window can drive it directly.

---

## [1.2] — 2026-05-28

**Build 1** · Tabbed preferences, calendar filters, banner redesign, themes, and fixes.

### Added

- **Per-calendar filter** — Calendars tab in Preferences lists all calendars from EKEventStore grouped by account (iCloud, Google, Exchange, On My Mac) with the same colors shown in Calendar.app. Toggle individual calendars off to suppress alerts from them. Persisted across launches.
- **Skip solo events** — toggle in Alerts tab suppresses alerts for events with no other attendees (blocked time, personal reminders). Off by default.
- **Two-line banner** — airplane banner shows the actual meeting title on the first line and participant names (`with Name`, `with A and B`, `with A, B +N more`) on a second smaller line. Solo events show title only.
- **Tabbed Preferences UI** — Preferences window replaced single long scroll with a four-tab toolbar (Alerts · Display · Calendars · General). Tab bar uses icon + label buttons with accent-colored selection highlight and full hit-area via `contentShape(Rectangle())`.
- **Calendar status in footer** — calendar access status indicator moved to the footer bar alongside Test and Quit actions.
- **"NOW" banner text** — when alert lead time is "On time" (0 min), banner reads "Meeting title NOW" instead of "Meeting title in 0 min".
- **Airplane themes** — five color presets (Classic, Sky, Forest, Sunset, Lavender) applied via `hueRotation` — tints both airplane and banner from the same artwork with no extra assets. Picker in Display tab shows mini airplane previews. Persisted across launches.
- **Preferences opens on click** — opening Preferences now dismisses the menu bar popover automatically via `NSApp.keyWindow?.orderOut(nil)`.
- **Click-through overlay** — `PassthroughHostingView` overrides `hitTest` so the full-width overlay panel only captures clicks over the actual airplane/banner content; clicks in the empty horizontal strip pass through to windows and apps beneath.

### Changed

- **Alert threshold sync** — `alertMinutesBefore` and `earlyAlertMinutes` `didSet` now update `poller.alertThresholds` synchronously, eliminating a race window where the old threshold could fire after a setting change.
- **Banner layout** — panel height increased from 110pt to 120pt; panel Y position now centers on `screenPositionPercent` (previously positioned from bottom edge). Title font 28pt → 26pt.
- **Alerts + Snooze merged** — Snooze settings moved into the Alerts tab, reducing tab count from five to four.
- **Quit button** — uses `power` SF Symbol, shortened label to "Quit".
- **Calendar grouping** — calendar list grouped by account with a separate `SettingsCard` per account, matching Apple Calendar's sidebar layout.

---

## [1.1] — 2026-05-28

**Build 2** · Settings overhaul, multi-screen, snooze, launch at login, and more.

### Added

- **Multi-screen support** — one airplane panel spawns per connected display; each panel uses the correct screen's width and frame, so all monitors get the alert simultaneously.
- **Configurable alert lead time** — pick when to be alerted: On time, 2, 5, 10, or 15 minutes before each meeting. Persisted across launches. Live-synced to the poller without restart.
- **Early warning** — optional second alert at a higher threshold (10 / 15 / 20 / 30 min). Off by default. When enabled, two flyovers appear per event: one at the early time, one at the main alert time.
- **Snooze** — tap the airplane during its flight to snooze the event. Window closes immediately, re-alerts after the configured snooze duration. Snooze duration is configurable: 2, 5, or 10 minutes. Pointing-hand cursor and a subtle scale-up on hover signal that the airplane is tappable.
- **Multi-meeting stagger** — when multiple meetings trigger alerts at the same poll tick, each subsequent airplane is delayed 5 seconds, preventing visual overlap.
- **Configurable screen position** — slider (Top → Bottom, 10%–90%) controls the vertical position of the airplane strip. Defaults to 65% from the bottom. Percentage shown live.
- **Sound** — plays the system "Ping" sound when an airplane appears. Toggle on/off from the menu. On by default.
- **Launch at login** — toggle in the menu registers or unregisters the app via `SMAppService.mainApp`. State reflects the actual system registration, not just a saved preference.
- **"On time" alert option** — 0-minute lead time added to the alert picker for meetings where you want a reminder exactly at start time.
- **Preferences window** — dedicated `NSWindow` (`PreferencesWindowController`) opened from the menu bar via Preferences…. Quiet Apps-style UI: `SettingsCard` section cards with `.regularMaterial` background and subtle border, `SettingsRow` rows with colored rounded-square icon badges.

### Changed

- **Display name** — `CFBundleDisplayName` set to `"Quiet Reminder"` (with space); Finder, Spotlight, System Settings, and the About panel now show the spaced name consistently.
- **`LSUIElement`** — set to `YES`; app no longer appears in the Dock or app switcher.
- **Menu bar popover** — stripped to minimal: calendar status, speed picker, Test airplane, Preferences…, Quit.
- **Menu bar icon** — reverted to custom `menubar` asset (SF Symbol `airplane` implies flight mode).
- **`CalendarPoller` internals** — refactored to `[Int]` thresholds array with composite `notifiedKeys` (`eventID_threshold`). Callback changed to batch `onMeetingsSoon`.
- **`AppController` internals** — `showAirplane` replaced by `handleBatch` + `showAirplaneNow`; window lifetime managed by `Task.sleep`.

---

## [1.0] — 2026-05-28

**Build 1** · Initial release as a Quiet Apps family member.

### Added

- **Flying banner alert** — a hand-drawn pink airplane glides across the screen trailing a banner with the meeting title, ~5 minutes before each calendar event. Renders in a borderless transparent `NSPanel` at screen-saver window level, floating above every window including fullscreen apps.
- **EventKit integration** — reads all calendars configured in Calendar.app (iCloud, Google, Exchange, or any combination) via Apple's EventKit framework. No API keys or separate OAuth setup needed.
- **Menu bar agent** — lives in the menu bar only (✈️ icon); no Dock icon.
- **Speed picker** — Slow / Normal / Fast flight duration, configurable from the menu.
- **Test mode** — trigger the animation on demand with a fake "Test Meeting" event directly from the menu.
- **60-second poller** — checks upcoming events every minute; an in-memory set prevents the same event from alerting twice.
- **Quiet Apps branding** — renamed from MeetingReminder to Quiet Reminder; bundle ID `app.quiet.QuietReminder`; README and project structure aligned to the Quiet Apps family standard.

---
