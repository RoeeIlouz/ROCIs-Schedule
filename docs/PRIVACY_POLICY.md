# Privacy Policy for ROCIs Schedule

**Last Updated: August 20, 2026**

ROCIs Schedule ("we," "our," or "the App") is committed to protecting your privacy. This Privacy Policy outlines how your information is collected, used, and safeguarded when using the ROCIs Schedule application.

---

## 1. Information We Collect

### A. Account & Authentication Data
- **Google Sign-In**: When you sign in using Google, we receive your email address, display name, and avatar URL via Firebase Authentication to create and secure your profile.
- **Firebase User ID (UID)**: A unique identifier assigned to your account to associate your academic schedule and courses across devices.

### B. User-Generated Academic Content
- **Courses**: Course titles, codes, instructors, credits, colors, and grades.
- **Schedule Events**: Class times, room locations, event types (lecture, lab, exam, study), and recurrence rules.
- **Assignments**: Task names, due dates, descriptions, priority levels, and completion status.
- **Imported Calendars (.ICS)**: Calendar events parsed from uploaded `.ics` files.

---

## 2. How Your Data Is Stored & Processed

- **Local Offline Database**: Your courses, schedules, and assignments are cached in a private SQLite database on your device (`rocis_schedule_<uid>.db`).
- **Cloud Firestore**: Data is synchronized securely with Google Cloud Firestore under your authenticated user scope (`users/{uid}/...`).
- **No Third-Party Advertising**: ROCIs Schedule does not sell, rent, or monetize your personal or academic information to advertisers.

---

## 3. App Permissions

- **Notifications (`POST_NOTIFICATIONS`)**: Used solely to schedule local class reminders, room location alarms, and assignment due date alerts on your device.
- **Internet Access**: Used exclusively to authenticate and synchronize academic data with Firebase Firestore.

---

## 4. Contact & Support

For privacy inquiries or account deletion requests, please contact:
- **Email**: support@rocisapps.com
- **Website**: https://rocisapps.com
