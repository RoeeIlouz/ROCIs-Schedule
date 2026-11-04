---
ontology: true
type: design
domain: rocis-schedule
summary: Sync a university .ics feed (first source - Afeka Yedion, behind SSO login) into ROCIs Schedule events, auto-applying changes with notifications
status: draft
tags: [calendar, ics, sync, afeka, notifications, background]
related: [SUMMARY]
discovered: 2026-11-04
---

# Calendar source sync (Afeka first)

## Intent

The user is an Afeka student. Their timetable changes during the semester (moved, cancelled, re-roomed lectures). They want ROCIs Schedule to follow those changes without manual edits, and to be told when something changes. The feature must not be Afeka-only: other students with any `.ics` feed should be able to use it.

## Facts established

- The Afeka link (`yedion.afeka.ac.il/.../PublicHours...&Google_Token=...`) redirects to `sso.afeka.ac.il` unless the request carries a signed-in Afeka session. Google Calendar subscription returns an empty calendar for the same reason. Opening it in a logged-in browser downloads an `.ics`; an incognito window does not.
- The `.ics` is regenerated on every request. It declares `REFRESH-INTERVAL` / `X-PUBLISHED-TTL` of 6 hours.
- Sample (157 events, `ignored/yedionICSFile_37166.ics`, git-ignored, contains personal data, never commit): every event is a single dated `VEVENT`, no `RRULE`. `UID`s were regenerated per fetch in the sample, so UID is not a stable identity across fetches (builder: re-verify with two fetches).
- Event shapes:
  - Class: `SUMMARY` = `<course name> <lecturer>` with no separator; `DESCRIPTION` = `סוג מפגש: <תרגול | סופי-הרצאה+תרגול ...> חדר לימוד: (מתקיים) קורס`; `LOCATION` = `<room> <building>` or `טרם נקבע`.
  - Cancelled: `SUMMARY` ends with `** השיעור מבוטל **`; `DESCRIPTION` may say `ישנה דחיה לתאריך לא ידוע`.
  - Exam: `SUMMARY` starts `מבחן מועד N בחינה`, `DESCRIPTION` says registered or not.
  - Non-class: holidays (`חגי ישראל ומועדיו`) and semester markers (`מועדי פתיחה וסיום סמסטרים`), `TRANSP:TRANSPARENT`.
- Existing app: `ScheduleEvent` (`lib/shared/models/schedule_models.dart`) is either one-time or weekly-recurring (`daysOfWeek`); there are no per-occurrence exceptions. `IcsImportService.parseIcsContent` already parses `.ics` into courses and events. No webview or background-task plugin is present. `http`, `shared_preferences`, `flutter_local_notifications`, `sqflite`, Firestore sync exist.

## Goals

1. Sign in to Afeka once inside the app; the app then fetches the feed with that session.
2. Periodically re-fetch, diff against the last synced copy, and apply changes automatically.
3. Post a notification that lists what changed (date, course, what changed).
4. Provider-agnostic core: a "calendar source" returns `.ics` text. Sources: Afeka (login) and a plain public `.ics` URL.
5. When the Afeka login expires, notify the user to sign in again instead of failing silently.

## Non-goals

- No per-occurrence exceptions for the user's own weekly sessions (separate future feature).
- No writing back to Afeka or to Google Calendar.
- No stored Afeka username or password. Only the session cookies the login produces.
- Holidays and semester markers are not imported.

## Anti-goals (would be a failure even if it works)

- Editing or deleting sessions the user made by hand, other than the one-time, user-approved replacement below.
- Duplicate sessions after a sync.
- Silent loss of the feed (login expired and nothing tells the user).
- Committing the feed token, cookies, or the sample `.ics`.

## Behaviour

**Setup.** Settings gets a "Calendar sync" entry. User picks Afeka (opens in-app sign-in at the feed URL; success = response is `.ics`) or "Public .ics link" (paste URL). The feed URL for Afeka is entered by the user once (it carries a personal token) and stored on device only, never in source or Firestore.

**Identity and diff.** Each synced event gets a source id and a stable key. Because UID is not stable (to be confirmed), the key is `normalized course name + start datetime + session kind`. Changes detected between two fetches: new, removed, time moved, room changed, lecturer changed, cancelled. A moved lecture appears as removed+new at the same course; the builder should pair them into one "moved" message when the course and kind match and one side is unmatched.

**Applying.** Synced events are stored as ordinary one-time `ScheduleEvent`s, tagged with source id and key, so the app owns only what it created. Courses are matched to existing courses by normalized name (lecturer stripped); an unmatched course is created. Existing course data (color, notes, grade, credits) is never overwritten. Cancelled sessions are kept and marked cancelled, not deleted.

**First sync.** The app lists existing weekly sessions it would replace (same course, overlapping the synced ones) and the user accepts or declines. Declined means the synced dated events are still added alongside, and the user is warned about possible duplicates.

**Event types.** Class/lab/practice map to existing `EventType`; exams map to `EventType.exam` for the user's registered moed only; unregistered moed entries are skipped.

**Schedule.** A background task runs about every 6 hours on Android; the app also syncs on open if the last sync is older than the interval. On a change it posts one notification summarizing changes. On an expired login (redirect to SSO) it posts one "sign in again" notification, once per expiry.

## Constraints

- Flutter, Shorebird-first: this change adds native plugins (in-app browser, background tasks, and possibly secure storage), so it ships as a full release to Play Internal Testing via `auto_cycle.py`, per `CLAUDE.md`. Confirm with the user before publishing.
- Bump `pubspec.yaml` and `lib/core/config/app_config.dart` together.
- All user-facing strings through `l10n.translate`, every supported language (the sample is Hebrew, the app supports RTL; keep bidi-safe text handling).
- Firestore rules stay owner-scoped; no public reads (domain rule).
- Background code must avoid UI-centric initialization and put timeouts on platform channel calls (`CLAUDE.md` rule 3).
- Cookies are secrets: stored in secure storage if added, else the best available private storage; never logged.
- Do not guess package versions; verify with `flutter pub add` / pub.dev.

## Decided by the user

- Changes are applied automatically with a notification.
- Existing weekly sessions are replaced by dated ones (approved in principle, with the first-sync approval step above as the builder's refinement for other users).
- Core stays generic; Afeka is one source.

## Left to the builder (my calls, mark in plan)

- Package choice for the in-app login and for background tasks, and whether cookies can be read back from the webview on both Android and iOS (Android is the target; iOS best effort).
- Exact normalization of course names and the lecturer-strip rule (Hebrew titles; lecturer starts with a title like `ד"ר`, `מר`, `גב'` or `פרופ'`; confirm against the sample).
- Storage of the last-synced snapshot (local database table vs file).
- Whether a failed-parse fetch (HTML login page returned with status 200) is detected by content sniffing for `BEGIN:VCALENDAR`.

## Risks to verify early

1. Session lifetime of the Afeka login and whether the SSO needs MFA or a captcha in a webview.
2. Whether a background task can reuse webview cookies (separate cookie jar). If not, fall back to foreground-only sync plus notification prompting the user to open the app.
3. UID stability across fetches.
