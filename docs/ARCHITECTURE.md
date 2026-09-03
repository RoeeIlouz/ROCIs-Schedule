# Architecture & Technical Design

This document details the system architecture, directory topology, state management patterns, and offline database synchronization in **ROCIs Schedule**.

---

## 🏛️ System Architecture Overview

ROCIs Schedule follows clean architectural separation between presentation (Screens/Widgets), state management (ChangeNotifiers/Providers), and local/remote data persistence layers:

```
┌─────────────────────────────────────────────────────────┐
│                     UI Layer (Flutter)                  │
│   ScheduleScreen │ CourseListScreen │ AssignmentScreen  │
└──────────────────────────┬──────────────────────────────┘
                           │ (Provider / Consumer)
┌──────────────────────────▼──────────────────────────────┐
│                    State & Providers                    │
│   ScheduleProvider │ CourseProvider │ AssignmentProvider│
└────────────┬─────────────────────────────┬──────────────┘
             │ (Local SQLite IO)           │ (Remote Cloud IO)
┌────────────▼─────────────┐ ┌─────────────▼──────────────┐
│     LocalDbService       │ │      FirestoreService      │
│  SQLite (isolated DB per │ │  users/{uid}/courses       │
│  user: rocis_schedule_   │ │  users/{uid}/events        │
│  <uid>.db)               │ │  users/{uid}/assignments   │
└──────────────────────────┘ └────────────────────────────┘
```

---

## 📁 Directory Structure

```
lib/
├── features/
│   ├── assignments/       # Assignment list, creation, priority management
│   ├── auth/              # Google Sign-In, Firebase Auth, login screen
│   ├── courses/           # Course list, GPA overview, course details
│   ├── onboarding/        # First-run onboarding flow & profile setup
│   ├── profile/           # Profile viewer & settings screen
│   └── schedule/          # Timetable grid, exam countdown, event creation
└── shared/
    ├── l10n/              # AppLocalizations (English, Hebrew, RTL)
    ├── models/            # Course, ScheduleEvent, Assignment models
    ├── services/
    │   ├── cross_app_bridge_service.dart # ROCIs Tasks inter-app bridge
    │   ├── firestore_service.dart        # Cloud Firestore sync
    │   ├── ics_import_service.dart       # iCalendar .ics parser
    │   ├── local_db_service.dart         # Offline SQLite database (schema v3)
    │   ├── notification_service.dart     # Local notifications & alarms
    │   └── sync_service.dart             # Bi-directional sync orchestrator
    ├── theme/             # Glassmorphism, Material You, AMOLED theme provider
    └── widgets/           # GlassContainer, AppButton, AppTextField
```

---

## 💾 Local SQLite Database Isolation & Schema

`LocalDbService` isolates user data into dedicated SQLite files based on user ID (`rocis_schedule_<uid>.db`):
- **Version 1**: Initial `courses` and `schedule_events` tables.
- **Version 2**: Added `assignments` table with `isCompleted` and `priority`.
- **Version 3**: Added `grade REAL` column to `courses` table for academic GPA calculations.

---

## 🔄 Bi-Directional Firestore Synchronization

`SyncService` orchestrates offline-first synchronization:
1. Performs local SQLite query for instant UI rendering.
2. Background sync fetches remote collections from `users/{uid}/...` and merges newly created records without duplicate keys.
3. Updates `CourseProvider`, `ScheduleProvider`, and `AssignmentProvider` state.
