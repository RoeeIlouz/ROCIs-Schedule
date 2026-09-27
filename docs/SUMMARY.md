## Accessibility Labels & Hosting Security Headers - v0.0.6+12 Patch 3 - 2026-09-27

#### Problems & Root Causes
* 10 icon-only buttons (back, close, clear, apply, password visibility) had no tooltip, so screen readers announced just "button".
* Color swatches in Add Event and the assignment filter tabs were bare `GestureDetector`s with no role, label or selected state.
* Firebase Hosting sent no security headers.

#### Solutions Applied
* Tooltips from `MaterialLocalizations` (back/close) or new keys `show_password`, `hide_password`, `apply`, `clear`, `color` in all 8 languages.
* `Semantics(button, selected, label)` around the swatches and filter tabs; color picker label and hints no longer hardcoded English.
* `firebase.json`: HSTS, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy` (no framing headers: the Firebase auth iframe shares the hosting site).

## ROCIs Tasks Sync Sign-In & Friend Request Rules - v0.0.6+12 Patch 2 - 2026-09-27

#### Problems & Root Causes
* Synced tasks were always empty: the `rocis-todo` secondary app was never signed in, so ROCIs Tasks' owner-only rules denied every read. The email fallback query was denied too.
* `friend_requests` allowed any signed-in user to create documents under any user, for a feature that doesn't exist yet.

#### Solutions Applied
* `AuthService` signs in to `rocis-todo` after each Schedule sign-in (Google access token; email/password retried), restores it silently on Android for existing sessions, and signs out of it on sign-out and account deletion. Failures only leave synced tasks empty.
* `TasksFirestoreService` reads as the `rocis-todo` user; `SyncedTasksProvider` reloads on `rocis-todo` auth changes. Email lookup removed.
* `friend_requests` is owner-only (rules deployed 2026-09-27). Web redeployed.

## Google Calendar Sync & Account Deletion - v0.0.6+12 Internal Release - 2026-09-26

#### Added
* **Google Calendar sync (Android)**: Settings > Google Calendar mirrors the schedule into a dedicated "ROCIs Schedule" calendar using the narrow `calendar.app.created` scope. `GoogleCalendarEventBuilder` formats each event (title "Course · Session", room as location, course/code, instructor, type, credits, semester, notes, nearest Google colour, popup reminder from settings, weekly RRULE bounded by the semester, device IANA time zone via `flutter_timezone`). `GoogleCalendarSyncService` reconciles the whole calendar with content hashes and hex-encoded stable event ids (idempotent; only changed events are written).
* Calendar-scoped Google Sign-In client: Android tokens only carry the scopes a client was configured with, so `requestScopes` alone never yields a usable Calendar token.
* In-app account deletion and privacy policy link (previously held for Patch 3).

#### Notes
* Released with `shorebird release` (not `auto_cycle.py`, which builds with plain Flutter and runs `git add .`), so 0.0.6+12 can receive Shorebird patches.
* Needs `calendar.app.created` on the OAuth consent screen before public use.

## Guest Cloud Isolation & Web Verification - v0.0.5+11 Patch 2 - 2026-09-26

#### Problems & Root Causes
* Guests (`effectiveUserId == 'guest'`) sent every edit to Firestore at `users/guest/...`; owner-only rules rejected them (`permission-denied`), but the writes should never have left the device.
* Desktop/web first run showed an empty week grid (the welcome card was phone-only); the desktop header's filter chips overflowed at 1280px.
* Web hosting had not been deployed since 2026-09-17.

#### Solutions Applied
* `FirestoreService._dbFor(uid)` returns null for the guest id, so all 14 read/write/listen paths no-op for guests.
* Desktop schedule shows `ScheduleWelcome` on first run; header split into a toolbar row and a filter row.
* Verified the web build in headless Chromium at 1280px and 400px: add course → reload → persisted, all tabs, sign-in page, no console errors.

## Guest-First Launch, Guest Data Migration & UX Overhaul - v0.0.5+11 Patch 1 - 2026-09-26

#### Problems & Root Causes
* **Login wall**: `AuthGate` sent every new user to `/login` before they could see the app.
* **Guest data lost on sign-in**: guests write to a separate `guest` SQLite DB; signing in switched providers to the account DB, orphaning everything made before. A first provider-level fix raced on the assignments→courses foreign key.
* **Phone schedule**: 7-day strip was 444px (clipped on phones), no way to change weeks, event cards not tappable, first-run screen was a grey "No events" and the + led to a red "no courses" error.
* **No editing** of events/assignments; adding an assignment with no courses dead-ended.
* **Desktop grid**: dropped events outside 08:00–20:00, drew overlaps on top of each other, ignored the 12/24h setting, slot taps ignored date/time. Screens chose phone/desktop by their own width while the shell used window width, so 850–1110px windows showed phone layouts in the desktop shell.

#### Solutions Applied
* Router opens `/schedule`; guest-session flag removed; sign-in via app-bar `AccountButton`, welcome card and settings; sign-out returns to guest mode.
* `GuestDataMigrator` (called from `AuthService._setUser` before the user switches) copies semesters → courses → events → assignments into the account DB, keeps the account's version on id clashes, uploads new records, deletes the guest DB.
* `ScheduleWelcome` / `FreeDayState`, equal-width swipeable week strip (RTL-aware), month-title date picker, tappable event cards with time range, undo on deletes.
* Edit routes `/schedule/edit-event`, `/assignments/edit`; `AddAssignmentScreen` shows an add-course prompt without courses.
* Grid: dynamic hour range, `layoutEventLanes` side-by-side overlaps, 12/24h labels, slot tap pre-fills the new event. Pages use the shell's window-width breakpoint.
* Shared ICS import dialog (paste button, localized, disposes its controller), Rubik fallback for Hebrew, glass tint capped at 18%, 44–48px touch targets, RTL swipe backgrounds, theme colors for course stats, 33 new strings × 8 languages.

#### Impact / Notes
* 174 tests pass (new: guest migration, lane layout, edit modes, FAB position, welcome state).

## Security: Owner-Only Firestore Rules - 2026-09-24

#### Problem
* `firestore.rules` (deployed, committed in `f822430`) allowed `read: if true` on `users/{uid}` and its courses, events, assignments and semesters so ROCIs Tasks could read schedules via unauthenticated REST — anyone with the public web API key could read any user's profile (incl. email), classes and assignments, and look users up by email.

#### Solution
* ROCIs Tasks now signs in to this project (its rocis-todo OAuth client IDs were safelisted under Authentication → Google → external client IDs) and reads with the owner's ID token (Tasks Patch 13).
* Rules restored to owner-only (`isOwner(userId)`) for the user doc and all subcollections; deployed and verified: anonymous event reads and email queries now return 403.

#### Impact / Notes
* ROCIs Tasks clients that haven't launched since Patch 13 lose schedule data until they open the app.
* Schedule accounts created with email+password are no longer readable by ROCIs Tasks (it signs in with Google).
* Rollback: `git show f822430:firestore.rules > firestore.rules && firebase deploy --only firestore:rules`.

## Live Cloud Sync, Semester-Bounded Export & v0.0.5+11 Internal Release - 2026-09-24

#### Problems & Root Causes
* **Changes never reached other devices**: `SyncService.performInitialSync` downloaded only when the device was empty, then never again; the Settings full sync never uploaded (`syncData()` returned early because `fullSync` had already set `_isSyncing`).
* **Semester dates lost/missing**: semesters were never downloaded but were re-uploaded on every `loadData`, so a fresh install's date-less defaults could overwrite dates set elsewhere; released builds never uploaded them at all (ROCIs Tasks had to hard-code Oct 25).
* **Exported calendars started classes on their creation date** with unbounded weekly RRULEs; TEXT fields were unescaped (commas/newlines corrupted events).
* **AddCourseScreen overflowed by 17px** on ~411dp phones (semester dropdown), hidden by tests that ran at the 1080dp wide layout.
* Every edit reloaded and re-uploaded all courses/events/semesters; awaited Firestore commits could hang saves offline; per-day occurrence checks rebuilt local DateTimes and scanned semesters for every event on every visible day.

#### Solutions Applied
* **Live cloud mirror** (`sync_service.dart`, `mirror_reconciler.dart`): Firestore is the source of truth, SQLite an instant-start cache reconciled per snapshot (cloud wins; local records missing from the cloud are deleted if previously server-confirmed, uploaded otherwise; cache snapshots never delete). Semesters mirrored too.
* Single-document, unawaited cloud writes; batched remote application (one notification); 500-write batch chunking; course deletion also removes its events locally; `SyncedTasksProvider` no longer recreated on every auth notification.
* ICS export bounded by semester start/end with RFC 5545 escaping.
* `CourseProvider.occursOn` with cached yyyymmdd semester bounds shared by the schedule screen and weekly grid.
* `AppConfig.appVersion` (synced by `bump_version.py`) replaces the stale hard-coded `v0.0.3` label.
* Committed the previously uncommitted Add Course/Assignment/Event redesign (`f822430`).

#### Known Issue
* `firestore.rules` allow public reads of user schedule data (for ROCIs Tasks' unauthenticated REST reads). To be closed after ROCIs Tasks authenticates to this project (its web secondary sign-in currently returns 400; likely an unsafelisted OAuth client ID).

#### Deployment
* `flutter analyze` 0 issues; 164/164 tests passing (16 new). `flutter build apk --debug` succeeds.
* No Shorebird release existed for 0.0.4+10 (it was built with plain `flutter build appbundle`), so this ships as an internal release built with `shorebird release android` — future Dart-only fixes can be Shorebird patches.

## Semester System, Course Management & v0.0.3+8 Release - 2026-09-12

#### Features & Architecture Implemented
* **Course Editing & Deletion**:
  - Full course editing via `AddCourseScreen` with pre-filled fields (`name`, `code`, `instructor`, `credits`, `color`, `semester`).
  - 3-dots popup menus on course cards and action buttons in course details sheet.
* **Semester Filtering & Custom Dates**:
  - `Semester` model and SQLite database upgrade to **Version 5** (`semesters` table, `courses.semester` column).
  - `SemesterDatesSheet` modal for setting custom start and end date ranges per semester.
  - Horizontal filter chips with dynamic credit hour and GPA recalculation.
  - Recurring schedule events bounded strictly to active semester dates.
* **Persistent Session & Launch Routing**:
  - `AuthGate` prevents unexpected sign-outs on app restart, honoring active Firebase and Guest sessions.
* **Google Play Internal Release**:
  - Bumped version to `v0.0.3+8`, built signed Android App Bundle (`app-release.aab`), and published to Google Play Console Internal Testing track.

## ROCIs Tasks Synergy & v0.0.2+7 Release - 2026-09-12

#### Features & Architecture Implemented
* **ROCIs Tasks Synergy (Beta)**:
  - Enabled two-way cross-app synergy with ROCIs Tasks.
  - Secret Easter Egg in `AboutAppDialog` (5 taps on version text) unlocks Beta Features and reveals "ROCIs Tasks Synergy (Beta)" toggle.
  - State persisted via `ThemeProvider` (`beta_features_unlocked` and `beta_tasks_integration`).
* **Cross-App Export**:
  - `CrossAppBridgeService`: 1-tap export from courses, assignments, and timetable events directly into ROCIs Tasks via deep link (`rocistasks://add_task`).
* **Firestore Cloud Sync**:
  - `TasksFirestoreService` & `SyncedTasksProvider`: Connects to `rocis-todo` secondary Firebase instance to fetch and synchronize active tasks.
* **UI Polish & Quality**:
  - Frosted glass styling, BouncyCheckbox micro-interactions, and Command Palette dialog.
  - Version bumped to `v0.0.2+7` in `pubspec.yaml`, `docs/CHANGELOG.md`, and Settings/About dialogs.

## 8-Language Localization Suite Parity - 2026-08-20

#### Goals / Requirements
* **8 Languages Fully Supported**: Added complete localized dictionaries for English (`en`), Hebrew (`he`), Spanish (`es`), German (`de`), French (`fr`), Arabic (`ar`), Hindi (`hi`), and Swedish (`sv`).
* **Settings Language Modal**: Integrated full language switcher with native titles and auto system default detection.
* **Testing**: Added `test/unit/l10n_test.dart` (36/36 tests passing, 0 analyzer issues).
## Authentication Suite & Guest Mode Parity - 2026-08-20

#### Goals / Requirements
* **Keystore signing fix**: Removed trailing whitespace in `key.properties` causing `Keystore was tampered with, or password was incorrect` during bundle compilation.
* **Email & Password Authentication**: Added email login, account registration (`/register`), and password reset email handling in `AuthService`.
* **Guest Mode Support**: Added "Skip for now" / Guest mode to `LoginScreen`, allowing users to use the timetable, assignments, and courses fully offline without forced login.
* **Profile & Settings Enhancements**: Handled guest states gracefully with prompt cards encouraging account creation for cloud sync.
* **Automated Tests**: 26/26 unit and widget tests passing with 0 analyzer issues.
# ROCIs Schedule - Project Errors & Changes Summary

This file summarizes errors encountered and changes made to the codebase, ensuring new sessions can quickly align on the project's state.

## Version 1.0.0 Initial Release & Ecosystem Architecture - 2026-08-20

#### Features Implemented
* **Timetable & Events Engine**: Weekly schedule viewer with day filter pills, recurring class slots, exams, labs, and study sessions.
* **Smart Notification Service**: Pre-class alerts (15m before), classroom locations, instructor alerts, and assignment due date reminders via `flutter_local_notifications` and `timezone`.
* **Exam Countdown**: Pinned horizontal carousel on `ScheduleScreen` for exams in the next 30 days with live countdown pills.
* **Academic GPA & Credit Calculator**: Added `grade` field to `Course` model, SQLite database migration v3, and glassmorphic **Academic Overview** cards in `CourseListScreen`.
* **ICS Calendar Importer**: `IcsImportService` parsing standard iCalendar `.ics` exports from Canvas/Moodle, extracting weekly rules, locations, and events.
* **Glassmorphism Design System**: `GlassContainer` with Gaussian blur, dynamic 10–18% course color tints, and dark/AMOLED theme modes.
* **Cross-App Synergy & Deep Linking**:
  - URL schemes: `rocisschedule://` and `https://schedule.rocisapps.com`.
  - `CrossAppBridgeService`: 1-tap export of assignments into `ROCIs Tasks` via `rocistasks://add_task`.
  - Ecosystem launcher tile in `SettingsScreen`.
* **Bi-directional Sync**: Offline SQLite database per user (`rocis_schedule_<uid>.db`) with remote Firestore synchronization for courses, schedule events, and assignments.
* **Automated Tests**: 22/22 unit and widget tests passing, 0 analyzer issues found.


