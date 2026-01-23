# Product Requirements Document: School Scheduling App

**Version:** 1.0  
**Last Updated:** January 23, 2026  
**Product Owner:** Engineering Student Team  
**Status:** Draft

---

## Executive Summary

A Flutter-based mobile scheduling application designed for students to manage their academic schedules, collaborate with classmates, and find common free time for group study sessions. The app leverages Firebase's free Spark plan for authentication and data storage while providing a modern Material 3 interface.

---

## Product Vision

Enable students to seamlessly manage their academic schedules while fostering collaboration through intelligent schedule comparison and availability matching, all within a beautifully designed, privacy-conscious mobile application.

---

## Target Audience

- **Primary:** College and university students aged 18-25
- **Secondary:** High school students with complex schedules
- **Tertiary:** Study group organizers and student clubs

---

## Success Metrics

- **Adoption:** 500 active users within first semester
- **Engagement:** 70% weekly active users
- **Retention:** 60% month-over-month retention
- **Performance:** App launch time < 2 seconds
- **Social:** Average user has 3+ friends added

---

## Technical Constraints

### Firebase Spark Plan Limitations
- **Firestore:** 50,000 reads/day, 20,000 writes/day, 20,000 deletes/day
- **Authentication:** Unlimited (Google Sign-In supported)
- **Storage:** 1GB total storage, 10GB/month bandwidth
- **Hosting:** 10GB storage, 360MB/day bandwidth
- **Cloud Functions:** Not available on Spark plan

### Design Implications
- Implement aggressive client-side caching to minimize reads
- Use compound queries and data denormalization to reduce query count
- Implement offline-first architecture with local database
- Batch write operations where possible
- No server-side scheduled tasks (Cloud Functions unavailable)

---

## Product Requirements

## 1. Core Features (MVP - Phase 1)

### 1.1 Authentication & Onboarding

#### 1.1.1 User Authentication
**Priority:** P0 (Critical)

**Requirements:**
- Google Sign-In integration via Firebase Auth
- Email/password authentication as fallback option
- Persistent login state with automatic re-authentication
- Sign out functionality
- Account deletion capability

**User Flow:**
1. User opens app
2. Presented with welcome screen showing app benefits
3. "Sign in with Google" button (primary CTA)
4. "Sign in with Email" button (secondary option)
5. After authentication, redirect to onboarding or main screen

**Firebase Usage:**
- Authentication: Unlimited (within Spark plan)
- User data stored in Firestore: ~1KB per user profile

**Acceptance Criteria:**
- User can sign in with Google in < 5 seconds
- User can sign in with email/password
- User remains signed in after app restart
- Error messages display for failed authentication
- Loading states shown during authentication

#### 1.1.2 Onboarding Flow
**Priority:** P0 (Critical)

**Requirements:**
- First-time user tutorial (skippable)
- Profile setup: Display name, university/school, graduation year
- Privacy settings introduction
- Request notification permissions

**Screens:**
1. Welcome screen with app overview
2. Quick tutorial (3 screens max, swipeable)
3. Profile creation
4. Permission requests
5. "Get Started" to main app

**Data Storage:**
```
users/{userId}
  - displayName: string
  - email: string
  - photoURL: string (from Google)
  - university: string
  - graduationYear: number
  - createdAt: timestamp
  - preferences: object
```

---

### 1.2 Schedule Management

#### 1.2.1 Schedule Creation & Editing
**Priority:** P0 (Critical)

**Requirements:**
- Create weekly recurring class schedules
- Add individual events (exams, deadlines, meetings)
- Edit existing schedule items
- Delete schedule items
- Color coding for different courses (8 preset colors)
- Course information: name, code, instructor, location, time

**Data Model:**
```
schedules/{userId}/courses/{courseId}
  - courseName: string
  - courseCode: string
  - instructor: string
  - color: string (hex)
  - credits: number
  - createdAt: timestamp

schedules/{userId}/events/{eventId}
  - title: string
  - courseId: string (reference)
  - type: enum (class, exam, lab, study, other)
  - startTime: timestamp
  - endTime: timestamp
  - location: string
  - building: string
  - room: string
  - daysOfWeek: array [0-6] (0=Sunday)
  - recurring: boolean
  - notes: string
  - color: string (inherited from course)
  - createdAt: timestamp
  - updatedAt: timestamp
```

**UI Requirements:**
- Week view as default (Material 3 Calendar component)
- Day view for detailed single-day schedule
- Month view for overview
- FAB (Floating Action Button) to add new event
- Long-press on event to edit/delete
- Drag-and-drop to reschedule (Phase 2)

**Firebase Optimization:**
- Query events by date range to minimize reads
- Cache current week locally (sqflite)
- Only fetch next/previous week on user navigation
- Estimated reads: ~100 reads/user/day with caching

**Acceptance Criteria:**
- User can create a recurring class in < 30 seconds
- Schedule displays correctly in all view modes
- Color coding is consistent across app
- Offline schedule viewing works
- Changes sync within 2 seconds when online

#### 1.2.2 Course Management
**Priority:** P0 (Critical)

**Requirements:**
- Add courses with details (name, code, instructor, credits)
- Assign colors to courses
- View course list
- Edit course details
- Delete courses (with confirmation if events exist)
- Archive courses for past semesters

**UI:**
- Dedicated "Courses" screen accessible from navigation
- List view with course color indicators
- Search/filter courses
- Bottom sheet for course details

**Acceptance Criteria:**
- User can add course in < 20 seconds
- Course deletion shows warning if events exist
- Course colors update across all events immediately

---

### 1.3 Theme & Design System

#### 1.3.1 Material 3 Theme Implementation
**Priority:** P0 (Critical)

**Requirements:**
- Full Material 3 design system implementation
- Dynamic color scheme (Material You on Android 12+)
- Custom color scheme for iOS and older Android
- Light and dark theme support
- System theme detection with manual override
- Smooth theme transitions

**Color Palette:**
```
Light Theme:
- Primary: Dynamic/Custom Blue (#2196F3)
- Secondary: Dynamic/Custom Teal (#009688)
- Tertiary: Dynamic/Custom Orange (#FF9800)
- Surface: #FFFFFF
- Background: #FAFAFA
- Error: #B00020

Dark Theme:
- Primary: Dynamic/Custom Light Blue (#64B5F6)
- Secondary: Dynamic/Custom Teal (#4DB6AC)
- Tertiary: Dynamic/Custom Orange (#FFB74D)
- Surface: #1E1E1E
- Background: #121212
- Error: #CF6679
```

**Components:**
- Use Material 3 components throughout (Cards, Buttons, AppBar, NavigationBar, etc.)
- Elevation system following Material 3 guidelines
- Typography using default Material 3 type scale
- Consistent 8dp spacing grid

**Theme Storage:**
```
users/{userId}/preferences
  - themeMode: enum (light, dark, system)
  - accentColor: string (optional custom color)
```

**Acceptance Criteria:**
- Theme persists across app restarts
- Theme switching is instant with no lag
- All components follow Material 3 guidelines
- Dynamic color works on supported devices
- AMOLED black option for dark theme (Phase 2)

---

### 1.4 Social Features & Schedule Sharing

#### 1.4.1 Friend System
**Priority:** P1 (High)

**Requirements:**
- Send friend requests by email or unique username
- Accept/decline friend requests
- View friend list
- Remove friends
- Privacy controls for schedule visibility

**Data Model:**
```
users/{userId}
  - username: string (unique, lowercase)
  - friendIds: array

friendRequests/{requestId}
  - fromUserId: string
  - toUserId: string
  - status: enum (pending, accepted, declined)
  - createdAt: timestamp
  - respondedAt: timestamp

friendships/{friendshipId}
  - userIds: array [userId1, userId2]
  - createdAt: timestamp
```

**UI:**
- Friends screen with tabs: Friends, Requests
- Search functionality to find users
- Friend request notifications
- Privacy toggle per friend (share full schedule vs. free time only)

**Firebase Optimization:**
- Limit friend list to 50 friends per user
- Use array-contains queries for efficient lookups
- Cache friend list locally
- Estimated reads: 10-20 reads per friend add/view

**Acceptance Criteria:**
- User can find and add friends by username
- Friend requests appear in real-time
- Privacy settings apply immediately
- Friend limit enforced with clear messaging

#### 1.4.2 Schedule Comparison
**Priority:** P1 (High)

**Requirements:**
- Compare schedule with one or multiple friends
- Visual overlay showing time conflicts and free time
- List view of common free time slots
- Filter by day of week
- Export common free times

**Comparison Modes:**
1. **One-on-one:** Compare with single friend
2. **Group:** Compare with multiple friends (max 5)
3. **Free time finder:** Show only common available slots

**UI:**
- Split-screen schedule view with transparency
- Color-coded overlaps (green = both free, red = one busy, gray = both busy)
- Bottom sheet with free time slots listed
- Toggle between overlay and side-by-side view

**Algorithm:**
- Client-side comparison to minimize Firestore reads
- Fetch friend schedules once, cache for comparison
- Calculate free time blocks (minimum 30-minute slots)

**Firebase Optimization:**
- Fetch friend schedules only when comparison initiated
- Cache comparison results for 1 hour
- Estimated reads: 50-100 reads per comparison session

**Acceptance Criteria:**
- Comparison loads in < 3 seconds
- Free time slots accurately calculated
- Visual overlay is clear and understandable
- Works offline with cached friend schedules

---

### 1.5 Notifications & Reminders

#### 1.5.1 Local Notifications
**Priority:** P1 (High)

**Requirements:**
- Reminder before class (configurable: 5, 10, 15, 30 min)
- Daily schedule summary notification (morning)
- Upcoming deadline reminders
- Custom notification sounds (default + 3 options)
- Notification settings per event type

**Implementation:**
- Use flutter_local_notifications package
- Schedule notifications locally (no Cloud Functions needed)
- Reschedule notifications on schedule changes
- Cancel notifications when events deleted

**Notification Types:**
1. **Class Reminder:** "CS101 starts in 15 minutes at Room 204"
2. **Daily Summary:** "You have 3 classes today: 9:00 AM, 1:00 PM, 4:00 PM"
3. **Deadline Alert:** "Assignment due tomorrow: CS101 Project"

**Settings:**
```
users/{userId}/preferences/notifications
  - enabled: boolean
  - classReminderMinutes: number
  - dailySummaryTime: string (HH:mm)
  - deadlineReminderDays: number
  - sound: string
```

**Acceptance Criteria:**
- Notifications arrive at correct times
- Notifications work when app is closed
- User can disable notifications per type
- Notification settings persist

---

## 2. Enhanced Features (Phase 2)

### 2.1 Advanced Schedule Features

#### 2.1.1 Multiple Semesters
**Priority:** P2 (Medium)

**Requirements:**
- Create multiple semester schedules
- Archive past semesters
- Switch between semesters
- Copy schedule to new semester

**Data Model:**
```
semesters/{userId}/terms/{termId}
  - name: string (e.g., "Fall 2024")
  - startDate: timestamp
  - endDate: timestamp
  - isActive: boolean
  - archived: boolean
```

#### 2.1.2 Schedule Templates
**Priority:** P2 (Medium)

**Requirements:**
- Save schedule as template
- Load template for new semester
- Share templates with friends
- Community templates (curated)

#### 2.1.3 Import/Export
**Priority:** P2 (Medium)

**Requirements:**
- Export schedule as iCal format
- Import from CSV (custom format)
- Share schedule as image
- Print-friendly PDF (Phase 3)

---

### 2.2 Academic Tracking

#### 2.2.1 Assignment Tracker
**Priority:** P2 (Medium)

**Requirements:**
- Add assignments with due dates
- Link to courses
- Mark as complete
- Priority levels
- Estimated time to complete

**Data Model:**
```
assignments/{userId}/tasks/{taskId}
  - title: string
  - courseId: string
  - dueDate: timestamp
  - priority: enum (low, medium, high)
  - estimatedHours: number
  - completed: boolean
  - completedAt: timestamp
  - notes: string
```

#### 2.2.2 Grade Tracking
**Priority:** P3 (Low)

**Requirements:**
- Track grades per course
- Calculate GPA
- Visualize grade trends
- Set grade goals

---

### 2.3 Social Enhancements

#### 2.3.1 Study Groups
**Priority:** P2 (Medium)

**Requirements:**
- Create study groups
- Invite members
- Group schedule view showing all members
- Suggest meeting times based on group availability
- Group chat (Phase 3)

**Data Model:**
```
groups/{groupId}
  - name: string
  - creatorId: string
  - memberIds: array
  - courseId: string (optional)
  - createdAt: timestamp

groupMeetings/{groupId}/meetings/{meetingId}
  - title: string
  - proposedTimes: array of timestamps
  - votes: map {userId: timestamp}
  - finalTime: timestamp
  - location: string
```

**Firebase Optimization:**
- Limit groups to 10 members
- Limit 20 groups per user
- Cache group data aggressively

#### 2.3.2 Campus Integration
**Priority:** P3 (Low)

**Requirements:**
- Campus map integration
- Building/room finder
- Walking time calculator
- Campus events calendar

---

## 3. Technical Architecture

### 3.1 Frontend Architecture

**Framework:** Flutter 3.16+  
**State Management:** Provider or Riverpod  
**Local Database:** sqflite  
**Navigation:** go_router

**Key Packages:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^2.24.0
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.0
  google_sign_in: ^6.2.0
  
  # UI
  material_color_utilities: ^0.8.0
  dynamic_color: ^1.7.0
  flutter_local_notifications: ^16.3.0
  
  # State & Storage
  provider: ^6.1.0
  sqflite: ^2.3.0
  shared_preferences: ^2.2.0
  
  # Utilities
  intl: ^0.18.0
  uuid: ^4.2.0
  connectivity_plus: ^5.0.0
```

### 3.2 Data Flow Architecture

**Offline-First Strategy:**
1. User action triggers local write to sqflite
2. UI updates immediately from local data
3. Background sync to Firestore when online
4. Listen to Firestore changes for multi-device sync
5. Conflict resolution: last-write-wins

**Caching Strategy:**
```
Local Cache (sqflite):
- Current user's schedule (all events)
- Friend list
- Friend schedules (viewed in last 7 days)
- User preferences

Firestore Queries:
- Initial load: Fetch current week
- Navigation: Fetch previous/next week as needed
- Friend comparison: Fetch friend's current week
- Sync: Listen to changes on current user's documents
```

### 3.3 Firebase Structure

```
firestore/
├── users/
│   └── {userId}/
│       ├── displayName: string
│       ├── email: string
│       ├── photoURL: string
│       ├── username: string (unique)
│       ├── university: string
│       ├── graduationYear: number
│       ├── friendIds: array
│       ├── preferences: map
│       └── createdAt: timestamp
│
├── schedules/
│   └── {userId}/
│       ├── courses/
│       │   └── {courseId}/
│       │       ├── courseName: string
│       │       ├── courseCode: string
│       │       ├── instructor: string
│       │       ├── color: string
│       │       ├── credits: number
│       │       └── createdAt: timestamp
│       │
│       └── events/
│           └── {eventId}/
│               ├── title: string
│               ├── courseId: string
│               ├── type: string
│               ├── startTime: timestamp
│               ├── endTime: timestamp
│               ├── location: string
│               ├── daysOfWeek: array
│               ├── recurring: boolean
│               ├── color: string
│               └── createdAt: timestamp
│
├── friendRequests/
│   └── {requestId}/
│       ├── fromUserId: string
│       ├── toUserId: string
│       ├── status: string
│       └── createdAt: timestamp
│
└── friendships/
    └── {friendshipId}/
        ├── userIds: array [userId1, userId2]
        └── createdAt: timestamp
```

**Firestore Indexes Required:**
```
Collection: schedules/{userId}/events
- startTime ASC, endTime ASC
- type ASC, startTime ASC
- courseId ASC, startTime ASC

Collection: friendRequests
- toUserId ASC, status ASC, createdAt DESC
- fromUserId ASC, status ASC, createdAt DESC

Collection: users
- username ASC (for search)
```

**Security Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can only read/write their own user document
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Users can only read/write their own schedules
    match /schedules/{userId}/{document=**} {
      allow read: if request.auth.uid == userId 
                  || request.auth.uid in get(/databases/$(database)/documents/users/$(userId)).data.friendIds;
      allow write: if request.auth.uid == userId;
    }
    
    // Friend requests
    match /friendRequests/{requestId} {
      allow read: if request.auth.uid == resource.data.fromUserId 
                  || request.auth.uid == resource.data.toUserId;
      allow create: if request.auth.uid == request.resource.data.fromUserId;
      allow update: if request.auth.uid == resource.data.toUserId;
      allow delete: if request.auth.uid == resource.data.fromUserId;
    }
    
    // Friendships
    match /friendships/{friendshipId} {
      allow read: if request.auth.uid in resource.data.userIds;
      allow create, delete: if request.auth.uid in request.resource.data.userIds;
    }
  }
}
```

### 3.4 Firebase Spark Plan Optimization

**Estimated Daily Firestore Operations (per active user):**

| Operation | Count/User/Day | Notes |
|-----------|----------------|-------|
| User profile read | 1 | On app start (cached) |
| Schedule reads | 50-100 | Week view with caching |
| Schedule writes | 5-10 | Creating/editing events |
| Friend list read | 2-5 | Cached aggressively |
| Friend schedule read | 20-40 | When comparing schedules |
| Notifications query | 0 | Handled locally |
| **Total Reads** | **73-146** | |
| **Total Writes** | **5-10** | |

**Scaling Analysis:**
- Spark Plan: 50,000 reads/day, 20,000 writes/day
- Safe user capacity: ~300-400 active daily users
- With optimizations: ~500-600 active daily users

**Optimization Strategies:**
1. **Aggressive Caching:** 7-day local cache of schedules
2. **Lazy Loading:** Only fetch data when needed
3. **Batch Operations:** Group multiple writes
4. **Query Efficiency:** Use compound indexes, limit results
5. **Offline Mode:** Full offline functionality with sync
6. **Read Minimization:** 
   - Cache friend schedules for 24 hours
   - Only sync changes, not full documents
   - Use snapshot listeners efficiently

**Monitoring Plan:**
- Firebase Console daily quota checks
- In-app analytics for read/write patterns
- Alert when approaching 80% of daily quota
- Upgrade path to Blaze plan documented

---

## 4. User Experience & Design

### 4.1 Navigation Structure

**Bottom Navigation (4 tabs):**
1. **Schedule** (Home) - Week/day/month view
2. **Courses** - Course management
3. **Friends** - Social features & comparison
4. **Profile** - Settings & preferences

**Top App Bar:**
- Dynamic title based on current screen
- Action buttons (contextual)
- Overflow menu for additional options

### 4.2 Key User Flows

#### Flow 1: Creating First Schedule
1. User signs in
2. Completes onboarding
3. Sees empty schedule with helpful message
4. Taps FAB to add course
5. Enters course details
6. Taps "Add Class Times"
7. Selects days, times, location
8. Saves
9. Schedule appears in week view

**Time to complete:** < 2 minutes

#### Flow 2: Comparing Schedules with Friend
1. User taps Friends tab
2. Searches for friend by username
3. Sends friend request
4. Friend accepts (notification)
5. User selects friend from list
6. Taps "Compare Schedules"
7. Sees overlay view with free times highlighted
8. Can export or create study session

**Time to complete:** < 1 minute after friend accepts

#### Flow 3: Daily Usage
1. User receives morning notification
2. Opens app to week view
3. Glances at today's schedule
4. Taps event for details
5. Gets reminder 15 min before class
6. Navigates to classroom

**Engagement:** 2-3 times per day

---

## 5. Privacy & Security

### 5.1 Data Privacy

**User Controls:**
- Complete schedule visibility on/off
- Per-friend privacy settings (full schedule vs. free time only)
- Public profile visibility (username searchable)
- Data export functionality
- Account deletion with data removal

**Data Collection:**
- Only collect necessary data for functionality
- No third-party analytics in MVP
- Firebase Analytics (anonymous) only
- No sale of user data

**Privacy Policy Requirements:**
- Clear disclosure of data collected
- Firebase services disclosure
- User rights explanation
- Contact information for privacy requests

### 5.2 Security Measures

**Authentication:**
- Firebase Auth best practices
- Secure token management
- Session timeout after 30 days

**Data Security:**
- Firestore Security Rules (see Section 3.3)
- HTTPS-only communication
- No sensitive data in local storage (passwords, tokens)
- Encrypted local database (sqflite with encryption)

**Input Validation:**
- Client-side validation for all inputs
- Server-side validation via Security Rules
- XSS prevention
- SQL injection prevention (prepared statements)

---

## 6. Testing Strategy

### 6.1 Unit Tests
- Business logic functions
- Data model serialization/deserialization
- State management
- Date/time calculations
- Coverage target: 70%+

### 6.2 Widget Tests
- Individual widget rendering
- User interactions
- State changes
- Coverage target: 60%+

### 6.3 Integration Tests
- Complete user flows
- Firebase integration
- Offline/online sync
- Multi-device sync

### 6.4 Manual Testing Checklist

**Pre-Release:**
- [ ] Sign in with Google (Android & iOS)
- [ ] Sign in with email/password
- [ ] Create schedule with 5+ courses
- [ ] Add friend and compare schedules
- [ ] Test offline mode
- [ ] Theme switching
- [ ] Notifications trigger correctly
- [ ] Data persists after app restart
- [ ] Multi-device sync works
- [ ] Security rules prevent unauthorized access

**Performance:**
- [ ] App launch < 2 seconds
- [ ] Schedule view renders < 500ms
- [ ] Schedule comparison < 3 seconds
- [ ] No ANR (Application Not Responding) errors
- [ ] Smooth 60fps scrolling

---

## 7. Release Plan

### 7.1 MVP Release (Phase 1) - Target: 6-8 weeks

**Week 1-2: Foundation**
- Project setup
- Firebase configuration
- Authentication implementation
- Basic UI structure with Material 3

**Week 3-4: Core Scheduling**
- Schedule data models
- Course management
- Event creation/editing
- Week/day/month views
- Local database implementation

**Week 5-6: Social Features**
- Friend system
- Schedule comparison
- Privacy controls
- Notifications

**Week 7-8: Polish & Testing**
- Bug fixes
- Performance optimization
- Testing
- Beta release to 20-30 users

**MVP Feature Set:**
- ✅ Google Sign-In & Email authentication
- ✅ Course and event management
- ✅ Week/day/month schedule views
- ✅ Light/dark Material 3 themes
- ✅ Friend system with privacy controls
- ✅ Schedule comparison (one-on-one)
- ✅ Local notifications
- ✅ Offline mode
- ✅ Multi-device sync

### 7.2 Phase 2 Release - Target: 3-4 months after MVP

**New Features:**
- Multiple semester support
- Group schedule comparison (up to 5 friends)
- Assignment tracker
- Schedule templates
- Enhanced notifications
- Import/export (iCal, CSV)
- Study group creation
- Improved search and filters

### 7.3 Phase 3 Release - Target: 6-8 months after MVP

**New Features:**
- Grade tracking
- Campus map integration
- Community schedule templates
- Advanced analytics
- Widgets (iOS & Android)
- Wear OS support
- Migration to Blaze plan with Cloud Functions
- Group chat
- Calendar integrations (Google Calendar, Outlook)

---

## 8. Success Criteria & KPIs

### 8.1 Launch Success Metrics (First Month)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Downloads | 200+ | App Store & Play Store |
| Active Users | 100+ | Weekly active |
| Retention (Week 1) | 60% | Users returning after 7 days |
| Average Session Time | 3+ minutes | Firebase Analytics |
| Schedules Created | 80+ | Firestore count |
| Friends Added | 150+ connections | Firestore count |
| Crash-Free Rate | 99%+ | Firebase Crashlytics |

### 8.2 Ongoing Success Metrics

**Engagement:**
- Daily Active Users (DAU)
- Weekly Active Users (WAU)
- Monthly Active Users (MAU)
- DAU/MAU ratio > 30%

**Feature Usage:**
- % users with 3+ courses added
- % users with 2+ friends
- % users who compared schedules
- Notification opt-in rate

**Performance:**
- Average app start time
- Firestore quota usage (% of Spark limits)
- Error rate
- Network success rate

**Satisfaction:**
- App Store rating > 4.3/5
- User feedback themes
- Feature request patterns

---

## 9. Risks & Mitigation

### 9.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Firebase Spark quota exceeded | Medium | High | Aggressive caching, monitoring, upgrade plan ready |
| Poor performance with large schedules | Low | Medium | Pagination, lazy loading, optimize queries |
| Offline sync conflicts | Medium | Medium | Last-write-wins, conflict UI notification |
| Multi-platform bugs | Medium | Medium | Comprehensive testing on both platforms |
| Google Sign-In issues | Low | High | Email fallback, clear error messages |

### 9.2 Product Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Low user adoption | Medium | High | Marketing plan, university partnerships, referral system |
| Users don't add friends | Medium | High | Onboarding emphasizes social features, easy friend discovery |
| Privacy concerns | Low | High | Clear privacy policy, granular controls, transparency |
| Competition from existing apps | High | Medium | Focus on simplicity, beautiful design, free tier |

### 9.3 Business Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Firebase costs on scale | High | Medium | Optimize early, plan migration to Blaze, consider alternatives |
| Platform policy violations | Low | High | Follow guidelines, regular policy reviews |
| COPPA compliance (if used by minors) | Medium | High | Age verification, parental controls, legal review |

---

## 10. Future Considerations

### 10.1 Monetization (Post-Launch)

**Potential Revenue Streams:**
1. **Freemium Model:**
   - Free: Basic features, 5 friends, 3 semesters
   - Premium ($2.99/month or $19.99/year):
     - Unlimited friends
     - Unlimited semesters
     - Advanced analytics
     - Priority support
     - Custom themes
     - Ad-free experience

2. **University Partnerships:**
   - Official campus integrations
   - Bulk licensing for institutions
   - Custom branding

3. **Affiliate Programs:**
   - Study material recommendations
   - Textbook links
   - Student discounts

### 10.2 Platform Expansion

- Web app (Flutter Web)
- Desktop apps (Windows, macOS, Linux)
- Browser extension
- API for third-party integrations

### 10.3 Advanced Features

- AI-powered schedule optimization
- Automatic schedule conflict detection
- Study habit analysis
- Productivity insights
- Integration with learning management systems (Canvas, Blackboard)
- Smart study time recommendations

---

## 11. Open Questions

1. Should we support multiple schools/universities in MVP or focus on single institution?
2. What is the minimum Android/iOS version we should support?
3. Should schedule comparison be limited to mutual friends only?
4. How do we handle timezone differences for remote/international students?
5. Should we implement rate limiting on friend requests to prevent spam?
6. Do we need email verification or is Google Sign-In sufficient?
7. Should archived semesters count against Firestore storage quota?

---

## 12. Appendix

### 12.1 Glossary

- **Semester/Term:** Academic period (Fall, Spring, Summer)
- **Course:** Class or subject (e.g., CS101)
- **Event:** Single occurrence on schedule (class, exam, meeting)
- **Schedule Comparison:** Overlaying multiple schedules to find common time
- **Free Time:** Time slots when all compared users are available
- **Recurring Event:** Event that repeats weekly
- **Spark Plan:** Firebase free tier

### 12.2 References

- [Material Design 3](https://m3.material.io/)
- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Firebase Spark Plan Limits](https://firebase.google.com/pricing)
- [Flutter Best Practices](https://flutter.dev/docs/development/best-practices)

### 12.3 Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Jan 23