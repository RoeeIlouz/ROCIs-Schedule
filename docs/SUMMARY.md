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


