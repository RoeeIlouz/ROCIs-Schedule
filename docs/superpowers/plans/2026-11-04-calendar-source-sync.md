---
ontology: true
type: plan
domain: rocis-schedule
summary: Task-by-task plan for syncing an .ics calendar source (Afeka first) into ROCIs Schedule with auto-applied changes and notifications
status: draft
tags: [calendar, ics, sync, afeka, plan]
related: [2026-11-04-calendar-source-sync-design]
discovered: 2026-11-04
---

# Calendar Source Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Periodically fetch a calendar `.ics` (Afeka Yedion behind SSO, or a public URL), diff it against the last copy, auto-apply changes to the user's schedule, and notify what changed.

**Architecture:** Pure-Dart core (parse, classify, diff, apply) with no Flutter dependencies, tested first. Thin adapters on top: a `CalendarSource` interface (public URL, Afeka-with-session), a webview login screen, a settings entry, notifications, and a background task. Synced events are ordinary one-time `ScheduleEvent`s with deterministic ids (UUID v5 of source id + key), so no database or Firestore schema change is needed and a second device converges on the same ids instead of duplicating.

**Tech Stack:** Flutter/Dart, existing `http`, `shared_preferences`, `uuid`, `flutter_local_notifications`, `provider`. New native plugins (versions verified with `flutter pub add`, not guessed): an in-app webview, a background-task plugin.

**Spec:** `docs/superpowers/specs/2026-11-04-calendar-source-sync-design.md`

## Global Constraints

- Full release (new native plugins), Play Internal Testing via `python .agent/skills/rocis-autonomous-release/scripts/auto_cycle.py --notes "<Description>" --category Added`. Confirm with the user before publishing. Not a Shorebird patch.
- Bump `pubspec.yaml` and `lib/core/config/app_config.dart` together (format `xx.yy.zz+build`).
- Every user-facing string via `l10n.translate('key')` in all five maps of `lib/shared/l10n/app_localizations.dart` (`en`, `he`, `es`, `de`, `ar`); no hardcoded UI strings.
- Platform channel calls during init and in background code use a 2 second timeout; background code skips UI initialization.
- Glass cards/dialogs use `GlassContainer` when glassmorphism is active.
- Firestore rules stay owner-scoped; do not add public reads.
- Feed URL, cookies, and the sample `.ics` are secrets: never in source, logs, tests, or commits. Tests use a synthetic fixture. `ignored/` stays git-ignored.
- No sudo. No emojis or em-dashes in code comments or docs.

## Review Focus

1. Login page returned with HTTP 200 instead of `.ics`: must be treated as "session expired", never parsed as an empty calendar (which would delete every synced event). Pinned in Task 5.
2. Empty or truncated feed that parses to zero entries while a snapshot exists: must not mass-delete; treat as a failed fetch. Pinned in Task 3.
3. Same lecture appearing twice (lecture plus practice at the same time, or duplicate entries): deterministic id collisions must not drop one silently. Pinned in Task 4.
4. Hebrew titles with bidi marks, extra spaces, or a trailing cancellation marker: course matching must be stable. Pinned in Task 2.
5. Two devices syncing the same account: same ids, no duplicates. Pinned in Task 4.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `lib/features/calendar_sync/models/feed_entry.dart` | `FeedEntry`, `EntryKind`, `SyncChange`, `ChangeKind`, `SyncSummary` |
| `lib/features/calendar_sync/services/feed_parser.dart` | `.ics` text to `List<FeedEntry>` raw fields |
| `lib/features/calendar_sync/services/afeka_classifier.dart` | Hebrew title rules: course name, lecturer strip, kind, cancelled, registered |
| `lib/features/calendar_sync/services/feed_differ.dart` | previous vs current entries to `List<SyncChange>` |
| `lib/features/calendar_sync/services/calendar_sync_service.dart` | orchestrates fetch, diff, apply, snapshot, notify |
| `lib/features/calendar_sync/services/calendar_source.dart` | `CalendarSource` interface, `PublicIcsSource`, `AfekaSource`, `FetchResult` |
| `lib/features/calendar_sync/services/sync_store.dart` | snapshot and settings persistence (`shared_preferences`) |
| `lib/features/calendar_sync/screens/afeka_login_screen.dart` | webview sign-in |
| `lib/features/calendar_sync/screens/calendar_sync_settings_screen.dart` | setup, status, sync now, first-sync review |
| `lib/features/calendar_sync/services/sync_scheduler.dart` | background task registration and entry point |
| `test/features/calendar_sync/*` | tests, plus `fixtures/synthetic_feed.ics` |

Existing files modified: `course_provider.dart`, `notification_service.dart`, `settings_screen.dart`, `app_localizations.dart`, `main.dart`, `pubspec.yaml`, `app_config.dart`, `AndroidManifest.xml` (if the plugins require it).

---

### Task 0: Spike - can the app reuse the Afeka login outside the webview?

Throwaway, labeled spike; nothing from it is kept except the answer recorded in the spec's "Risks" section.

**Files:**
- Modify: `docs/superpowers/specs/2026-11-04-calendar-source-sync-design.md` (record result)

- [ ] **Step 1:** `flutter pub add` the webview plugin and read its docs for cookie access; record the resolved version and whether `HttpOnly` cookies are readable on Android.
- [ ] **Step 2:** In a scratch branch, open the feed URL in a webview, sign in, and test two ways to get the `.ics`: (a) read cookies and call it with `http`; (b) run the fetch from inside the webview (JavaScript `fetch` with credentials) and return the text.
- [ ] **Step 3:** Record: which of (a)/(b) works, how long the session lasts (retry after 1 hour and next day), whether SSO asks for MFA or a captcha, and whether two fetches return the same `UID`s.
- [ ] **Step 4:** Decide and write into the spec: if (a) works, background sync uses cookies. If only (b) works, background sync is limited to a notification asking the user to open the app, and the foreground sync uses (b). Commit the spec update only.

**Produces:** a recorded decision `cookieFetch: true|false` that Tasks 5, 6 and 8 follow.

---

### Task 1: Models and `.ics` feed parser

**Files:**
- Create: `lib/features/calendar_sync/models/feed_entry.dart`, `lib/features/calendar_sync/services/feed_parser.dart`
- Test: `test/features/calendar_sync/feed_parser_test.dart`, `test/features/calendar_sync/fixtures/synthetic_feed.ics`

**Interfaces:**
- Produces: `class FeedEntry { final String summary, description, location, uid; final DateTime start, end; final bool transparent; }`; `enum EntryKind { lecture, practice, lab, exam, skip }`; `class FeedParser { static List<FeedEntry> parse(String ics); static bool looksLikeCalendar(String body); }`.

- [ ] **Step 1:** Create `synthetic_feed.ics` with invented content mirroring the real shapes (a lecture, a practice, a cancelled lecture with the Hebrew marker `** השיעור מבוטל **`, an exam with `.רשום למבחן`, a holiday with `TRANSP:TRANSPARENT`, a folded long line, `TZID=Asia/Jerusalem` times).
- [ ] **Step 2:** Write failing tests: `parses all VEVENTs`, `unfolds continuation lines`, `reads TZID local times as wall-clock DateTime`, `marks TRANSP:TRANSPARENT entries transparent`, `looksLikeCalendar is false for an HTML login page and true for BEGIN:VCALENDAR (with BOM or leading whitespace)`, `parse of garbage returns empty list without throwing`.
- [ ] **Step 3:** Run `flutter test test/features/calendar_sync/feed_parser_test.dart`; expected FAIL (missing files).
- [ ] **Step 4:** Implement the models and `FeedParser`. Reuse the unfolding and date helpers' approach from `IcsImportService` (`lib/shared/services/ics_import_service.dart`, `_parseDateTime`); duplicate the few lines rather than coupling to its Course-producing output.
- [ ] **Step 5:** Re-run; expected PASS. Commit `feat(calendar-sync): add feed models and ics parser`.

---

### Task 2: Afeka classifier

**Files:**
- Create: `lib/features/calendar_sync/services/afeka_classifier.dart`
- Test: `test/features/calendar_sync/afeka_classifier_test.dart`

**Interfaces:**
- Consumes: `FeedEntry`, `EntryKind` (Task 1).
- Produces: `class Classified { final String courseName; final String lecturer; final EntryKind kind; final bool cancelled; final bool registered; }`; `class AfekaClassifier { static Classified classify(FeedEntry e); static String normalizeName(String raw); }`.

- [ ] **Step 1:** Write failing tests with invented course/lecturer names in the real format:
  - `strips lecturer after course name when lecturer starts with ד"ר, מר, גב' or פרופ'`
  - `keeps a course name that contains digits (e.g. "חשבון דיפרנציאלי אינטגרלי1")`
  - `detects practice from DESCRIPTION "סוג מפגש: תרגול" and lecture from "הרצאה"`
  - `cancelled when SUMMARY has "** השיעור מבוטל **", and the marker is removed from lecturer/course`
  - `exam entries: kind exam, registered true for ".רשום למבחן", false for ".לא רשום למבחן"`
  - `TRANSPARENT entries (holidays, semester markers) classify as skip`
  - `normalizeName removes bidi control chars (U+200E, U+200F, U+202A-U+202E) and collapses whitespace`
- [ ] **Step 2:** Run; expected FAIL.
- [ ] **Step 3:** Implement. Lecturer rule: find the first token that is one of the title prefixes and cut from there. An unmatched title keeps the whole string as the course name (never throw).
- [ ] **Step 4:** Re-run; PASS. Commit `feat(calendar-sync): add afeka entry classifier`.

---

### Task 3: Differ

**Files:**
- Create: `lib/features/calendar_sync/services/feed_differ.dart`
- Test: `test/features/calendar_sync/feed_differ_test.dart`

**Interfaces:**
- Consumes: `FeedEntry`, `Classified`.
- Produces: `enum ChangeKind { added, removed, moved, roomChanged, lecturerChanged, cancelled, restored }`; `class SyncChange { final ChangeKind kind; final String course; final DateTime when; final String? detail; }`; `class SyncKeyed { final String key; final FeedEntry entry; final Classified info; }`; `class FeedDiffer { static String keyFor(Classified c, FeedEntry e); static List<SyncChange> diff(List<SyncKeyed> previous, List<SyncKeyed> current); }`. `keyFor` = `normalizedCourse|startIso|kind`.

- [ ] **Step 1:** Write failing tests: `identical feeds give no changes`, `new entry is added`, `missing entry is removed`, `same course and kind, different start: one moved change (not added+removed)`, `room text change gives roomChanged with detail "old -> new"`, `cancel marker appearing gives cancelled; disappearing gives restored`, `two entries with the same key (lecture and practice at identical time) are both retained and not reported as changes when stable`, `empty current with non-empty previous returns a single sentinel exception FeedLooksEmpty (caller treats as failed fetch)` - implement as `diff` throwing `FeedLooksEmpty`.
- [ ] **Step 2:** Run; FAIL.
- [ ] **Step 3:** Implement `diff` with a multimap keyed by key; pair unmatched removed/added by (course, kind) nearest in time to form `moved`.
- [ ] **Step 4:** PASS. Commit `feat(calendar-sync): add feed differ`.

---

### Task 4: Apply changes to the schedule

**Files:**
- Create: `lib/features/calendar_sync/services/sync_store.dart`, `lib/features/calendar_sync/services/calendar_sync_service.dart` (apply half)
- Modify: `lib/features/courses/course_provider.dart` (add `Future<void> applySyncBatch({required List<Course> courses, required List<ScheduleEvent> upserts, required List<String> deleteIds})` which writes DB, upserts the list, uploads to cloud via `_cloud`, and calls `notifyListeners()` once)
- Test: `test/features/calendar_sync/apply_test.dart`

**Interfaces:**
- Consumes: Tasks 1-3 types; `CourseProvider`.
- Produces: `class SyncStore { Future<List<SyncKeyed>> loadSnapshot(String sourceId); Future<void> saveSnapshot(String sourceId, List<SyncKeyed>); Future<DateTime?> lastSync(String sourceId); ... }`; `String syncedEventId(String sourceId, String key)` using `Uuid().v5(Uuid.NAMESPACE_URL, '$sourceId|$key')`; `class CalendarSyncService { Future<SyncSummary> applyEntries(String sourceId, List<FeedEntry> feed); }`.

- [ ] **Step 1:** Write failing tests against an in-memory `CourseProvider` fixture (follow `test/unit/provider_lifecycle_test.dart` setup):
  - `matches an existing course by normalized name and never overwrites its color/notes/grade`
  - `creates a course for an unmatched name`
  - `synced events use syncedEventId and are upserted, not duplicated, on a second run`
  - `two devices (two providers, same feed) produce identical event ids`
  - `cancelled entry is kept with the localized cancelled title prefix and grey color`
  - `removed entries delete only events whose ids are in the snapshot; hand-made events untouched`
  - `skip-kind entries and unregistered exam moeds are not imported`
  - `lecture and practice at the same minute both survive (key includes kind)`
  - `first run with existing weekly sessions for matched courses returns them in SyncSummary.replaceCandidates and does not delete them until applyReplacement(ids) is called`
- [ ] **Step 2:** Run; FAIL.
- [ ] **Step 3:** Implement `SyncStore` over `SharedPreferences` (snapshot as JSON per source id) and `applyEntries`. Event type mapping: lecture/practice to `EventType.classType`, lab to `EventType.lab`, exam to `EventType.exam`. Cancelled title prefix and grey color are this plan's call.
- [ ] **Step 4:** PASS. Commit `feat(calendar-sync): apply feed changes to schedule`.

---

### Task 5: Sources and fetch

**Files:**
- Create: `lib/features/calendar_sync/services/calendar_source.dart`
- Test: `test/features/calendar_sync/calendar_source_test.dart`

**Interfaces:**
- Produces: `sealed class FetchResult` with `FetchOk(String body)`, `FetchNeedsLogin()`, `FetchFailed(String reason)`; `abstract class CalendarSource { String get id; Future<FetchResult> fetch(); }`; `class PublicIcsSource implements CalendarSource` (constructor `PublicIcsSource(Uri url, {http.Client? client})`); `class AfekaSource implements CalendarSource` (constructor takes the feed `Uri` and a `Future<String?> Function() cookieHeader` per the Task 0 decision).

- [ ] **Step 1:** Write failing tests with `package:http/testing.dart` `MockClient`:
  - `200 with BEGIN:VCALENDAR gives FetchOk`
  - `302 to a host containing "sso" gives FetchNeedsLogin`
  - `200 HTML login page gives FetchNeedsLogin (not FetchOk)` (Review Focus 1)
  - `timeout / SocketException gives FetchFailed`
  - `request carries the Cookie header and never logs it`
- [ ] **Step 2:** FAIL. **Step 3:** Implement with `followRedirects: false` handling and a 20 second timeout. **Step 4:** PASS. Commit `feat(calendar-sync): add calendar sources`.

---

### Task 6: Orchestration, notifications, settings and login UI

**Files:**
- Modify: `lib/shared/services/notification_service.dart` (add `Future<void> showSyncChanges(List<SyncChange> changes)` and `Future<void> showLoginExpired()`, each with fixed ids so repeats replace instead of stacking), `lib/features/profile/settings_screen.dart` (new "Calendar sync" tile), `lib/shared/l10n/app_localizations.dart` (all five maps), `lib/main.dart`, `pubspec.yaml`
- Create: `afeka_login_screen.dart`, `calendar_sync_settings_screen.dart`
- Complete: `calendar_sync_service.dart` (`Future<SyncSummary> run(CalendarSource source)` composing fetch, parse, classify, diff, apply, snapshot, notify)
- Test: `test/features/calendar_sync/sync_run_test.dart`, `test/unit/l10n_test.dart` coverage for new keys (existing test checks key parity; extend if needed)

**Interfaces:**
- Consumes: Tasks 1-5.
- Produces: `CalendarSyncService.run(CalendarSource)`; settings keys in `SyncStore`: `feedUrl`, `sourceType`, `lastSyncAt`, `needsLogin`.

- [ ] **Step 1:** Write failing tests with fake source and fake notifier:
  - `FetchOk with changes applies and calls notifier once with all changes`
  - `FetchOk with no changes does not notify`
  - `FetchNeedsLogin notifies login-expired once, then stays silent until a successful run resets the flag`
  - `FetchFailed leaves snapshot and events untouched and does not notify`
  - `empty parsed feed with non-empty snapshot is treated as failed (FeedLooksEmpty), nothing deleted` (Review Focus 2)
- [ ] **Step 2:** FAIL. **Step 3:** Implement `run`. Add webview plugin via `flutter pub add` (verify the resolved name/version), build the login screen (loads the feed URL, finishes when the loaded body passes `FeedParser.looksLikeCalendar`, stores cookies or fetched body per Task 0). Build the settings screen: choose source, paste public URL, Afeka feed URL field (stored in `SyncStore` only), "Sync now", last sync time, and the first-sync review sheet listing `replaceCandidates` with Replace / Keep both. Add l10n keys in every map, including RTL-safe text.
- [ ] **Step 4:** `flutter test test/features/calendar_sync test/unit/l10n_test.dart`; PASS. Commit `feat(calendar-sync): sync orchestration, notifications and settings UI`.

---

### Task 7: Background and on-open scheduling

**Files:**
- Create: `lib/features/calendar_sync/services/sync_scheduler.dart`
- Modify: `lib/main.dart`, `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml` (only if the plugin requires it; native change, hence full release)
- Test: `test/features/calendar_sync/sync_scheduler_test.dart`

**Interfaces:**
- Produces: `class SyncScheduler { static Future<void> registerPeriodic(); static Future<void> cancel(); static bool isDue(DateTime? lastSync, DateTime now, {Duration interval = const Duration(hours: 6)}); }` and a top-level background entry-point function annotated for the plugin.

- [ ] **Step 1:** Write failing tests for `isDue` only (`null last sync is due`, `5h59m not due`, `6h due`). The plugin wiring is verified manually in Task 8.
- [ ] **Step 2:** FAIL. **Step 3:** Add the background-task plugin with `flutter pub add` (verify name/version). Implement `isDue`, `registerPeriodic` (about 6 hours, requires network), and the entry point: initialize only what sync needs (SharedPreferences, notifications, local DB) with 2 second timeouts on platform calls; if Task 0 recorded `cookieFetch: false`, the entry point only posts the "open the app to sync" notification when due. Call `isDue` and `run` on app open from `main.dart`/provider load when a source is configured. Register in `main.dart` only when a source is configured; cancel when the user turns sync off.
- [ ] **Step 4:** PASS. Commit `feat(calendar-sync): background and on-open scheduling`.

---

### Task 8: Verify, version, release

**Files:**
- Modify: `pubspec.yaml`, `lib/core/config/app_config.dart`, `docs/SUMMARY.md` (changelog entry per existing style)

- [ ] **Step 1:** `flutter analyze` and `flutter test`; expected: no new analyzer issues, all tests pass.
- [ ] **Step 2:** `python .agent/scripts/checklist.py .`; expected: pass.
- [ ] **Step 3:** Build and install a debug APK on a device; with the real Afeka feed: sign in, run Sync now, confirm the first-sync review lists the weekly sessions, accept, confirm the schedule shows dated sessions; change nothing and sync again (no notification, no duplicates); simulate expiry (clear webview data) and confirm the "sign in again" notification; confirm a background run after the interval (or trigger it via the plugin's debug mechanism).
- [ ] **Step 4:** Bump the version in `pubspec.yaml` and `app_config.dart` together; add the changelog entry.
- [ ] **Step 5:** Ask the user to confirm, then run `python .agent/skills/rocis-autonomous-release/scripts/auto_cycle.py --notes "Calendar source sync (Afeka login + public ICS), auto-applied changes with notifications" --category Added`.
- [ ] **Step 6:** Commit `added: Calendar source sync (v<new version>)`.
