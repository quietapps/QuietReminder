# Changelog

All notable changes to **Quiet Reminder** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
