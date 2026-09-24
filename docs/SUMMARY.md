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


