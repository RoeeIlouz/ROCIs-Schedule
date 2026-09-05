# Changelog

All notable user-facing changes to ROCIs Schedule are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
