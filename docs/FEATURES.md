# Features Deep Dive

This document outlines the core capabilities of **ROCIs Schedule** and details their design, interaction, and technical implementation.

---

## 🗓️ Weekly Class Timetable & Schedule Engine

_Implementation: `lib/features/schedule` and `lib/features/schedule/schedule_provider.dart`_

- **Week Strip Navigation**: Highlighting the selected day of the week with animated active pill selectors.
- **Event Types**:
  - `classType` (Lectures / Recitations)
  - `lab` (Laboratory sessions)
  - `exam` (Midterm & Final examinations)
  - `study` (Study blocks & group sessions)
- **Visual Timetable Cards**: Formatted start/end times, room locations, instructor tags, and course-specific color branding.
- **Empty States**: Encouraging prompts with 1-tap event/course creation actions.

---

## 🚨 Pinned Exam Countdown Carousel

_Implementation: `lib/features/schedule/schedule_screen.dart`_

- **Live Assessment Detection**: Automatically aggregates upcoming `EventType.exam` items within the next 30 days.
- **Countdown Badges**: Live calculation of remaining days and hours (`"In 3 days"`, `"Tomorrow"`, `"Today at 10:00"`).
- **Exam Details**: Highlights course tag, room location, and exact start time with glassmorphic crimson accent glows.

---

## 🔔 Smart Class & Assignment Reminders

_Implementation: `lib/shared/services/notification_service.dart`_

- **Pre-Class Alarms**: Configured via `flutter_local_notifications` and `timezone` to notify students 15 minutes before classes.
- **Notification Content**: Includes course name, lecture topic, classroom room number, and instructor.
- **Assignment Due Date Reminders**: Alarms scheduled 1 day prior to assignment due dates.
- **Settings Toggle**: Live toggle in `SettingsScreen` and `ThemeProvider` to enable/disable notifications.

---

## 🎓 GPA & Academic Performance Calculator

_Implementation: `lib/features/courses` and `lib/shared/models/schedule_models.dart`_

- **Academic Overview Cards**: Glassmorphic metric cards on `CourseListScreen` displaying Total Credits, GPA (4.0 scale), and Weighted Average Grade.
- **Interactive Grade Setting**: Tap-to-edit grade modal bottom sheet for each course.
- **Credit Weighting**: Automatically weights grades by course credit units.

---

## 📅 University `.ICS` Calendar Importer

_Implementation: `lib/shared/services/ics_import_service.dart`_

- **Universal Import**: Supports `.ics` iCalendar text files exported from Canvas, Moodle, and Google Calendar.
- **Intelligent Parsing**: Parses `VEVENT`, weekly recurrence rules (`RRULE:FREQ=WEEKLY;BYDAY=...`), timestamps, locations, and descriptions.
- **Course Auto-Grouping**: Deduplicates courses, extracts course codes, and assigns aesthetic ROCIs color palettes.

---

## 🎨 Glassmorphism & Adaptive Theming

_Implementation: `lib/shared/widgets/glass_container.dart` and `lib/shared/theme`_

- **Dynamic Color Tinting**: 10–18% tint of individual course colors blended with Gaussian blur over dark/AMOLED backgrounds.
- **Themes**: System Default, Light, Dark, and true AMOLED pitch black modes.
- **Dynamic Color**: Material You color extraction from Android wallpaper palettes via `dynamic_color`.
- **RTL & Localization**: Full English and Hebrew support with RTL layouts (`app_localizations.dart`).

---

## 🔗 Cross-App Synergy with ROCIs Tasks

_Implementation: `lib/shared/services/cross_app_bridge_service.dart` and `android/app/src/main/AndroidManifest.xml`_

- **Deep Link Schemes**: `rocisschedule://` and `https://schedule.rocisapps.com`.
- **1-Tap Assignment Export**: Outbox icon on assignment cards exports assignment titles, deadlines, priorities, and course categories directly to `ROCIs Tasks` via `rocistasks://add_task`.
- **Ecosystem Integration**: Direct launcher tile in `SettingsScreen` connecting users across ROCIs Suite apps.
