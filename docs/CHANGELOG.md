# Changelog

All notable user-facing changes to ROCIs Schedule are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.7+13] - 2026-09-28 (Patch 1)

### Changed
- The version in Settings and About now shows the running patch (e.g. v0.0.7 P1).

## [0.0.7+13] - 2026-09-28

### Added
- Share courses by QR code or link: https://schedule.rocisapps.com/share links open the app (web fallback), offline or 7-day cloud links, import preview with semester picker

## [0.0.6+12] - 2026-09-27 (Patch 3)

### Changed
- Better screen reader support: back, close, clear and show/hide password buttons are labeled, and color choices and assignment filters announce themselves and whether they're selected.

## [0.0.6+12] - 2026-09-27 (Patch 2)

### Fixed
- Your open ROCIs Tasks tasks now show up in Schedule. Signing in also connects your ROCIs Tasks account (same Google account or email), and signing out disconnects it.

## [0.0.6+12] - 2026-09-27 (Patch 1)

### Fixed
- Google Calendar sync no longer creates a duplicate calendar when turned off and on, and classes land on the same dates the schedule shows. Sync errors now explain what went wrong.

## [0.0.6+12] - 2026-09-26

### Added
- Google Calendar sync (classes with room, instructor and course details in a dedicated ROCIs Schedule calendar), in-app account deletion, privacy policy link

## [0.0.5+11] - 2026-09-26 (Patch 2)

### Fixed
- Guest data now stays entirely on your device until you sign in (no cloud requests as a guest). Desktop and web: new users see the welcome card, and the schedule filters get their own row so nothing is cut off.

## [0.0.5+11] - 2026-09-26 (Patch 1)

### Changed
- No login wall: the app opens on your schedule and signing in is optional. Anything you add before signing in moves into your account. New welcome screen, swipeable week strip, tap-to-open events, edit events and assignments, undo deletes, and a smarter desktop timetable (overlaps, all hours, 12/24h).

## [0.0.5+11] - 2026-09-24

### Fixed
- Your schedule now syncs live across all your devices (edits and deletions included), semester dates are kept in sync, calendar export starts classes at the semester start, redesigned Add Course/Assignment/Event screens, and faster schedule views.

## [0.0.4+10] - 2026-09-17

### Added
- **Student-Worker Hybrid Calendar**: Multi-domain event classification (Academic, Work, Personal) with dedicated properties, custom color palettes, and domain icons.
- **Real-Time Schedule Collision Engine**: Live conflict detection warning when work shifts or appointments collide with lectures, labs, or exams.
- **Desktop & Web Workspace UX**: Full responsive layout with sidebar navigation rail, KPI summary metrics, and desktop Command Palette (`Ctrl+K`).
- **Database Schema v6**: Seamless local SQLite migration supporting custom event colors and domains with backwards compatibility.
- **Localization Parity**: 100% string coverage across 8 languages (English, Hebrew, Spanish, German, French, Arabic, Hindi, Swedish) with dynamic RTL support.

### Fixed & Hardened
- **Firestore Security Rules**: Fully authenticated and UID-isolated access control across courses, events, and assignments.
- **Web UI Clean-Up**: Removed redundant mobile glassmorphism and Material You artifacts for a crisp, responsive web experience.

## [0.0.3+9] - 2026-09-13

### Fixed
- Automatic Firestore sync for timetable events, enabling live integration with ROCIs Tasks.

## [0.0.3+8] - 2026-09-12

### Added
- Course management: edit and delete courses directly from cards and detail sheet.
- Semester filters: filter courses by semester with start/end date bounds and dynamic GPA tracking.
- Timetable bounds: recurring schedule events automatically align with semester dates.
- Persistent session: retain user authentication and guest mode on app launch.

## [0.0.2+7] - 2026-09-12

### Added
- ROCIs Tasks synergy: export assignments and timetable events directly to your task list with one tap.
- Real-time cloud sync with ROCIs Tasks to view active tasks within Schedule.
- Secret beta features toggle in the About screen.
- Fresh frosted glass UI refinements, dynamic color themes, and quick command shortcuts.

## [0.0.1+6] - 2026-09-05

### Fixed
- Preserve Google Sign-In and Play Services Auth classes in R8/ProGuard, add profile scopes, and clear stale auth sessions

## [0.0.1+5] - 2026-09-05

### Fixed
- Configured Google Sign-In with explicit `serverClientId` (Firebase Web Client ID) for reliable authentication and token retrieval.

## [0.0.1+4] - 2026-09-04

### Fixed
- Fixed release crash by enabling MultiDex, keep rules, and notification receivers.
- Added safe locale resolution fallback on launch.

## [0.0.1+3] - 2026-09-04

### Fixed
- Fixed Android startup crash on Google Play release installs.
- Synchronized Firebase configuration with official application package identifier.

## [0.0.1+1] - 2026-08-20

### Added

- Complete academic timetable management with course color coding.
- Smart class notifications & location alerts 15 minutes before lectures.
- Live exam countdown carousel for upcoming assessments.
- Academic GPA tracker and credit hours overview.
- University `.ics` calendar importer (Canvas, Moodle, Google Calendar).
- Premium glassmorphic interface with AMOLED dark mode support.
- Deep linking & 1-tap assignment export to ROCIs Tasks.
