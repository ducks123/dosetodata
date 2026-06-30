# Executive Summary

- Overall production readiness score: 5.5 / 10
- Biggest strengths:
  - Clear local-first privacy posture: no analytics SDKs, no crash SDK, and no obvious path sending medication names, doses, mood scores, check-in answers, or side-effect text to third parties.
  - RevenueCat purchase handling has explicit cancellation and silent-restore outcomes, which addresses a common v5 paywall bug.
  - The core SwiftUI product surface is coherent, and the recent move from legacy `Test` to `MedChangeEvent` is directionally simpler.
  - The project builds successfully and the existing unit test passes on the iPhone 17 simulator.
- Biggest risks:
  - The app can delete the user's only local health history after a SwiftData container failure.
  - "Expired means read-only" is not enforced consistently across the app.
  - Local notification cleanup is incomplete when medications are stopped, deleted, or dose-changed.
  - Insights bucketing and marker math can hide current-day/current-week medication changes.
  - There is effectively no automated coverage for the highest-risk logic.

Verification performed:

```sh
xcodebuild test -project DoseToData.xcodeproj -scheme DoseToData -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -skipPackagePluginValidation
```

Result: build succeeded; 1 test executed; 1 passed.

# Critical Issues

## C1. SwiftData crash recovery can permanently erase local health history

- Severity: Critical
- Category: Correctness, Data loss, Privacy
- Files: `DoseToData/App/DoseToDataApp.swift:31-66`
- Description: If `ModelContainer` creation fails, the app deletes every file matching `default.store`, `.sqlite`, `.sqlite-wal`, and `.sqlite-shm` from Application Support and Documents, then retries. If that still fails, it falls back to an in-memory store.
- Why it matters: DoseToData's privacy promise is that health data is stored locally. That makes the local SwiftData store the user's only copy. A migration bug, transient file-system error, partial iOS restore, disk issue, or SwiftData compatibility problem could destroy years of mood, medication, dose, adherence, and side-effect history without user consent or a recoverable backup.
- Recommended solution: Never auto-delete the production store on launch. Replace this with explicit versioned migrations, a backup-and-quarantine flow, and a user-facing recovery path. If the store cannot open, copy the existing store files to a timestamped safe location, surface an error/recovery screen, and avoid writing an in-memory replacement over the user's expectations. Add migration tests for every schema change.
- Estimated implementation difficulty: Hard

# High Priority Issues

## H1. Expired subscription state is not actually read-only

- Severity: High
- Category: Correctness, Revenue, State management
- Files: `DoseToData/Services/SubscriptionService.swift:16-20`, `DoseToData/Views/Today/TodayView.swift:116-119`, `DoseToData/Views/Today/TodayView.swift:360-365`, `DoseToData/Views/Today/TodayView.swift:502-505`, `DoseToData/Views/Schedule/ScheduleView.swift:29-31`, `DoseToData/Views/Schedule/ScheduleView.swift:81-84`, `DoseToData/Views/Today/CheckInDetailView.swift:114-115`, `DoseToData/Views/Schedule/MedScheduleEditorView.swift:70-113`
- Description: New check-ins and new medication changes in Today call `requireSubscription()`, but Schedule can still open medication editing and schedule editing with no subscription guard. Existing check-ins can also be edited from `CheckInDetailView` without checking `sub.status.canWrite`. Additionally, `.loading` returns `true` for `canWrite`, giving a cold-start window where an expired user can write before RevenueCat finishes refreshing.
- Why it matters: The product model says expired users are in read-only mode. Incomplete enforcement allows expired users to add, stop, edit, and reschedule medications or update existing check-ins. It also makes future paywall changes fragile because every write surface has to remember to gate itself.
- Recommended solution: Centralize write access. Either route every mutating sheet/button through a single `WriteGate`/`LockedFeatureButton`, or inject a write-policy service into save paths so mutation is blocked even if a sheet is presented. Make `.loading` fail closed for writes, or cache the last known entitlement locally and only allow loading writes when the last known state was writable. Add tests for every write entry point.
- Estimated implementation difficulty: Medium

## H2. Medication reminders are leaked after stop/delete and can contain stale doses

- Severity: High
- Category: Correctness, Notifications, Data consistency
- Files: `DoseToData/Views/Today/EditMedicationsSheet.swift:143-153`, `DoseToData/Views/Onboarding/MedicationsOnboardingStepView.swift:57-60`, `DoseToData/Views/Today/LogMedChangeSheet.swift:427-437`, `DoseToData/Services/ReminderManager.swift:64-97`, `DoseToData/Services/ReminderManager.swift:99-107`
- Description: `ReminderManager.scheduleReminders` correctly clears a medication's existing pending requests before scheduling new ones. However, stopping a medication in `EditMedicationsSheet`, deleting an onboarding medication, and stopping a medication through `LogMedChangeSheet` do not call `clearReminders`. Dose changes update `UserMedication.currentDose` but do not reschedule existing notifications, so notification bodies can keep the old dose text.
- Why it matters: A psychiatric medication app must not keep reminding a user to take a stopped medication or show a stale dose in a notification. That is a clinical safety and trust issue, even if the app does not recommend doses.
- Recommended solution: Treat reminder lifecycle as part of the medication mutation transaction. On stop/delete, call `clearReminders(for:)` after a successful save. On dose change, reschedule reminders so notification copy matches the new dose. Add tests or a debug verification helper that asserts pending notification identifiers after add/edit/stop/delete flows.
- Estimated implementation difficulty: Medium

## H3. Insights medication-change markers can disappear from current day/week charts

- Severity: High
- Category: Correctness, Charts, Date handling
- Files: `DoseToData/Views/Today/LogMedChangeSheet.swift:20`, `DoseToData/Views/Today/LogMedChangeSheet.swift:109`, `DoseToData/Views/Today/LogMedChangeSheet.swift:357`, `DoseToData/Views/Insights/InsightsView.swift:763-773`, `DoseToData/Views/Insights/InsightsView.swift:469-470`, `DoseToData/Views/Insights/InsightsView.swift:634-635`
- Description: Chart data points are bucketed to the start of the day/week, and `chartXDomain` aligns the domain end to the start of the current bucket. Medication-change `RuleMark`s use the raw `MedChangeEvent.date`. A change logged today at a non-midnight time, or during the current week after the week-start timestamp, can be outside the visible domain even though it belongs to the visible bucket.
- Why it matters: Medication-change markers are one of the app's core explanatory tools. If a user logs a medication change and the marker does not appear in Insights, the app undermines the "DoseToData" value proposition.
- Recommended solution: Normalize event dates at save time for date-only events, or render marker x-values through the same `bucketKey(for:)` logic used by the chart series. Also filter marker chips to the visible scope and add deterministic tests for day/week/month/year bucket boundaries.
- Estimated implementation difficulty: Medium

## H4. Side effects are not saved or edited against the selected check-in day

- Severity: High
- Category: Correctness, Data integrity
- Files: `DoseToData/Views/Today/DailyCheckInSheet.swift:120-134`, `DoseToData/Views/Today/DailyCheckInSheet.swift:483-486`, `DoseToData/Models/SideEffectEntry.swift:12-17`, `DoseToData/Views/Today/CheckInDetailView.swift:38-40`
- Description: `DailyCheckInSheet` hydrates existing check-in answers and adherence state, but not existing side effects. On save, every pending side effect is inserted with `SideEffectEntry`'s default `Date()`, not the `targetDate`. Editing a past check-in therefore records side effects on today, and editing an existing check-in can append duplicate side-effect rows without a way to reconcile or remove the old ones.
- Why it matters: Side effects are health data. Assigning them to the wrong day corrupts trend analysis and can make historical check-in detail views omit the side effect the user just entered.
- Recommended solution: Load side effects for `targetDate` into editable state, save new side effects with `date: calendar.startOfDay(for: targetDate)` or the intended timestamp, and reconcile existing rows on update. Consider making side effects children of `DailyCheckIn` if their lifecycle is tied to check-in edits.
- Estimated implementation difficulty: Medium

# Medium Priority Issues

## M1. Medication-change edit/delete leaves timeline and current medication state inconsistent

- Severity: Medium
- Category: Correctness, Data consistency
- Files: `DoseToData/Views/Today/LogMedChangeSheet.swift:343-349`, `DoseToData/Views/Today/LogMedChangeSheet.swift:372-375`, `DoseToData/Views/Insights/MedChangeMarkerDetailSheet.swift:64-67`
- Description: Creating a `MedChangeEvent` mutates `UserMedication` for start/stop/dose-change actions. Editing an existing event intentionally does not reapply those changes, and deleting an event only deletes the marker. The current medication list can therefore reflect a change that no longer exists in the medication-change timeline.
- Why it matters: Users will reasonably expect their medication history and current medication list to agree. Divergence makes Insights markers, Recent Changes, and Schedule tell different stories.
- Recommended solution: Choose one model explicitly. Either make medication-change events historical-only and require separate medication-list edits, or implement reversible commands that know how to apply, undo, and reapply changes transactionally. At minimum, warn users when editing/deleting a change will not update current medications.
- Estimated implementation difficulty: Hard

## M2. Many persistence and notification failures are silently swallowed

- Severity: Medium
- Category: Error handling, Maintainability
- Files: `DoseToData/Views/Today/EditMedicationsSheet.swift:49`, `DoseToData/Views/Today/EditMedicationsSheet.swift:153`, `DoseToData/Views/Onboarding/MedicationsOnboardingStepView.swift:59`, `DoseToData/Views/Onboarding/MedicationsOnboardingStepView.swift:112`, `DoseToData/Views/Onboarding/MedicationsOnboardingStepView.swift:134`, `DoseToData/Views/Schedule/MedScheduleEditorView.swift:75`, `DoseToData/Views/Schedule/MedScheduleEditorView.swift:243`, `DoseToData/Views/Schedule/MedScheduleEditorView.swift:314`, `DoseToData/Views/Schedule/MedScheduleEditorView.swift:346`, `DoseToData/Views/Schedule/MedScheduleEditorView.swift:352`, `DoseToData/Services/ReminderManager.swift:94`, `DoseToData/Services/ReminderManager.swift:140`, `DoseToData/Services/ReminderManager.swift:170`, `DoseToData/Services/ReminderManager.swift:213`
- Description: Multiple user-visible writes use `try? modelContext.save()` or `try? await center.add(request)`. The UI then dismisses or continues as though the operation succeeded.
- Why it matters: Silent save failures are hard to diagnose and especially harmful in a health-tracking app: users believe they recorded something that may not exist. Silent notification failures mean users can miss medication reminders with no explanation.
- Recommended solution: Introduce small save/schedule helpers that return typed errors and drive user-visible alerts. Reserve `try?` for genuinely optional best-effort work. Add lightweight internal logging that avoids health payloads but records operation type and failure reason.
- Estimated implementation difficulty: Medium

## M3. Daily and adherence records have no per-day uniqueness invariant

- Severity: Medium
- Category: Correctness, Data modeling
- Files: `DoseToData/Models/DailyCheckIn.swift:176-193`, `DoseToData/Models/MedAdherenceLog.swift:7-22`, `DoseToData/Views/Today/DailyCheckInSheet.swift:43-45`, `DoseToData/Views/Today/DailyCheckInSheet.swift:175-177`, `DoseToData/Services/NotificationDelegate.swift:57-68`
- Description: `DailyCheckIn` and `MedAdherenceLog` are unique only by UUID. Code enforces one record per calendar day by fetching the first same-day row in memory. Concurrent quick actions, double taps, import/restore flows, or future sync could create duplicate records for the same local day.
- Why it matters: Once duplicate daily records exist, Today and Insights will use whichever record appears first, averages can double-count, and adherence status can become nondeterministic.
- Recommended solution: Add a persisted normalized day key such as `yyyy-MM-dd` in the user's calendar/time zone and enforce uniqueness at the model layer. Build an idempotent upsert helper for check-ins and adherence logs, and add a one-time dedupe migration.
- Estimated implementation difficulty: Medium

## M4. Week and bucket math uses inconsistent calendars

- Severity: Medium
- Category: Correctness, Date handling
- Files: `DoseToData/Views/Today/TodayView.swift:45-58`, `DoseToData/Views/Insights/InsightsView.swift:99`, `DoseToData/Views/Insights/InsightsView.swift:805-808`, `DoseToData/Views/Insights/InsightsView.swift:875-877`
- Description: Today uses an ISO calendar with Monday as first weekday for date-strip state, while Insights uses `Calendar.current` for week ranges and bucket keys. In the United States, `Calendar.current` commonly starts weeks on Sunday.
- Why it matters: The same user data can land in different week buckets depending on the screen and locale. This is exactly the kind of off-by-one issue that makes charts feel untrustworthy.
- Recommended solution: Create a shared `AppCalendar`/`DateBucketer` utility with explicit calendar identifier, time zone policy, and first weekday. Use it in Today, Insights, adherence logs, and tests.
- Estimated implementation difficulty: Medium

## M5. Insights can include future check-ins outside the visible chart domain

- Severity: Medium
- Category: Correctness, Charts
- Files: `DoseToData/Views/Today/TodayView.swift:67-70`, `DoseToData/Views/Insights/InsightsView.swift:823-827`
- Description: Today explicitly allows future-dated check-ins to appear in the date strip. Insights filters records with `ci.date <= end + 1 day`, which can include tomorrow's check-in even when the chart domain ends at today/current bucket.
- Why it matters: Trend percentages can be based on a point the user cannot see, and charts can become confusing when future simulation data exists.
- Recommended solution: Make future-data behavior explicit. Either exclude future check-ins from Insights by default, or extend the visible domain and label it clearly. Use an end-of-day helper instead of adding one day to an arbitrary `Date()`.
- Estimated implementation difficulty: Easy

## M6. Local trial day calculation can expire users early and starts before onboarding completion

- Severity: Medium
- Category: Correctness, Subscription
- Files: `DoseToData/App/DoseToDataApp.swift:77-79`, `DoseToData/Services/SubscriptionService.swift:210-224`, `DoseToData/Services/SubscriptionService.swift:231-242`
- Description: `refresh()` runs on app launch, before onboarding completes. For a brand-new install, `localTrialDaysLeft()` starts the local trial clock immediately. Later, remaining days are computed with `.day` components from `Date()` to expiry, which floors partial days; with less than 24 hours remaining, the local trial can become `0` and map to `.expired`.
- Why it matters: Users can lose trial time before they have actually started using the app, and the last calendar day of access can be cut short.
- Recommended solution: Start the local fallback trial only after onboarding/paywall entry, and gate write access by exact expiry timestamp rather than floored day count. Separately compute display copy such as "last day" from calendar dates.
- Estimated implementation difficulty: Easy

## M7. Legacy Test code is still compiled and partly wired

- Severity: Medium
- Category: Maintainability, App Store risk
- Files: `DoseToData/App/DoseToDataApp.swift:20-21`, `DoseToData/Views/Today/TodayView.swift:16`, `DoseToData/Views/Today/TodayView.swift:160-162`, `DoseToData/Views/Today/TodayView.swift:433-480`, `DoseToData/Views/Today/CreateTestSheet.swift:4-838`, `DoseToData/Views/Insights/EditTestSheet.swift:4-206`, `DoseToData/Views/Insights/InsightsView.swift:90`, `DoseToData/Views/Insights/InsightsView.swift:136-137`, `DoseToData/Views/Insights/InsightsView.swift:787-790`
- Description: `CreateTestSheet`, `EditTestSheet`, `Test`, `ScaleResponse`, `selectedTestID`, and old Today helpers remain compiled even though the feature is retired. Some of this dead UI still contains common-dose chip selection.
- Why it matters: Dead compiled flows raise maintenance cost, make refactors riskier, and preserve code that conflicts with the current App Store 1.4.2 strategy of not showing dose suggestions. Even if normal UI no longer reaches it, stale state and future edits can accidentally re-expose it.
- Recommended solution: Decide on a compatibility boundary. Keep the model only as long as required for historical data, but remove retired creation/editing UI and stale state. If historical rendering is still needed, create a small read-only legacy module.
- Estimated implementation difficulty: Medium

## M8. Test coverage is not production-grade

- Severity: Medium
- Category: Testing
- Files: `DoseToDataTests/DoseToDataTests.swift:4-16`, `project.yml:74-83`
- Description: The repository has one unit test, and it only verifies that `MedicationLibrary.json` decodes and has at least 80 entries.
- Why it matters: The highest-risk areas are all logic-heavy and regression-prone: subscription entitlements, date bucketing, reminder lifecycle, SwiftData migrations, and medication-change state transitions. None are covered.
- Recommended solution: Add focused unit tests around pure logic first: `SubscriptionService` status/outcome mapping with a RevenueCat adapter, `DateBucketer`, reminder identifier generation, daily/adherence upsert behavior, and medication-change apply/undo semantics. Then add a small UI test smoke suite for onboarding, check-in, schedule edit, and paywall gating.
- Estimated implementation difficulty: Medium

# Low Priority Issues

## L1. Paywall and marketing copy still mention retired "tests"

- Severity: Low
- Category: Product consistency, Maintainability
- Files: `DoseToData/Views/Subscription/PaywallView.swift:280-286`, `docs/support.html:36-46`, `docs/index.html:871-926`
- Description: The paywall feature list and public docs still refer to custom tracking tests, while the app has moved to medication-change events.
- Why it matters: Users may subscribe expecting a feature that is being retired, and App Review/support materials can drift from actual product behavior.
- Recommended solution: Update paywall, support, and landing-page copy to use medication changes and Insights markers, or restore a clear user-facing custom-test feature.
- Estimated implementation difficulty: Easy

## L2. Settings/account copy overstates cloud sync behavior

- Severity: Low
- Category: Privacy, Product consistency
- Files: `DoseToData/Views/Settings/AuthSheet.swift:155-162`, `DoseToData/Views/Settings/SettingsView.swift:168`, `DoseToData/PrivacyInfo.xcprivacy:54-66`
- Description: The app says data is stored locally and sign-in links an account to the device, while delete-account copy refers to "all synced data from our servers" and the privacy manifest says email is collected when the user opts into cloud backup/sync. The code reviewed does not implement health-data sync.
- Why it matters: Privacy messaging needs to be extremely precise for a mental-health/medication app.
- Recommended solution: Align all copy around the actual behavior: authentication/subscription account only, unless sync exists. If sync is planned but not shipped, do not describe it as current behavior.
- Estimated implementation difficulty: Easy

## L3. Production code prints seeding output

- Severity: Low
- Category: Privacy, Logging hygiene
- Files: `DoseToData/Services/MedicationSeeder.swift:51`
- Description: The app prints the medication library seed count to stdout.
- Why it matters: This does not expose user health data, but production logging should be intentional and payload-safe.
- Recommended solution: Remove the print or wrap it in debug-only logging.
- Estimated implementation difficulty: Easy

## L4. RevenueCat configuration is called from refresh paths

- Severity: Low
- Category: Architecture, Subscription
- Files: `DoseToData/Services/SubscriptionService.swift:64-70`, `DoseToData/Services/SubscriptionService.swift:74-79`, `DoseToData/App/DoseToDataApp.swift:77-79`, `DoseToData/Views/Subscription/PaywallView.swift:240-253`, `DoseToData/Views/Settings/SettingsView.swift:174-177`
- Description: `SubscriptionService.configure()` is called inside `refresh()`, and `refresh()` is triggered from app launch, paywall presentation, and settings.
- Why it matters: RevenueCat SDK setup should be a one-time app-lifecycle concern. Repeated configuration makes behavior harder to reason about and can produce subtle SDK-state surprises across updates.
- Recommended solution: Configure RevenueCat once during app startup and make `refresh()` only fetch customer info and offerings. Add a guard if repeated calls are retained defensively.
- Estimated implementation difficulty: Easy

# Technical Debt

- Large SwiftUI files have too many responsibilities: `DailyCheckInSheet.swift` (1143 lines), `InsightsView.swift` (1115 lines), `EditMedicationsSheet.swift` (847 lines), and `PaywallView.swift` (799 lines). Extracting pure view models/date helpers would make the riskiest code testable.
- Date handling is scattered across views. A shared calendar/bucketing layer would reduce bugs in Today, Insights, adherence logs, and notification scheduling.
- Domain mutations are performed directly in views. Medication add/stop/dose-change, check-in save, side-effect save, and reminder scheduling should be represented as small services or use-case objects with tests.
- Legacy `Test` compatibility has no clear boundary. The codebase needs a documented retirement plan: keep read-only migration support, remove creation/editing UI, then eventually migrate or archive the model.
- There is no CI evidence in the repo. A generated Xcode project plus SPM dependencies should have a reproducible `xcodegen generate` and `xcodebuild test` workflow.
- SwiftData schema evolution is not treated as a first-class production concern. A local-only app needs migration fixtures and disaster-recovery tests.

# Quick Wins

- Call `ReminderManager.shared.clearReminders(for:)` when a medication is stopped or deleted.
- Save side effects from `DailyCheckInSheet` with `date: calendar.startOfDay(for: targetDate)`.
- Gate Schedule medication editing and existing check-in edits behind the same subscription guard as Today creation flows.
- Filter Insights marker chips to the visible scoped range.
- Normalize `MedChangeEvent.date` to start of day when saving date-only events.
- Remove `CreateTestSheet` and the stale `showingCreateTest` sheet wiring if no user path should create legacy tests.
- Replace the `print` in `MedicationSeeder` with debug-only logging or remove it.
- Add tests for `SubscriptionStatus.canWrite`, local trial expiry, and RevenueCat purchase outcome mapping.
- Add tests for day/week/month/year bucket keys with fixed calendars and time zones.
- Add a CI command in docs or a workflow that runs `xcodegen generate` and `xcodebuild test`.

# Overall Recommendation

Do not treat this repository as fully production-ready for a long-lived, local-first health app until the data-loss path, write-access enforcement, reminder lifecycle, and date-bucketing issues are fixed. The current app can ship small updates if these risks are understood, but the next quality push should focus on correctness and testability rather than new features.

The privacy posture is a real strength: there is no obvious analytics/crash pipeline leaking sensitive health content. The main production risk is local integrity: preserving the user's only data copy, keeping reminders aligned with medication state, and making charts faithfully reflect the user's timeline.

# Top 10 Improvements

1. Replace destructive SwiftData crash recovery with safe migration, backup, and user-facing recovery.
2. Centralize subscription write gating and enforce read-only mode in every mutating flow.
3. Fix medication reminder lifecycle for add, edit, stop, delete, and dose-change operations.
4. Extract and test a shared date/bucketing utility for Today, Insights, adherence logs, and markers.
5. Normalize medication-change marker dates or render them through bucket keys so Insights never hides current-period events.
6. Repair side-effect save/edit semantics for past and existing check-ins.
7. Introduce per-day uniqueness/upsert behavior for check-ins and adherence logs.
8. Remove or quarantine retired Test creation/editing code.
9. Replace silent `try?` persistence and notification calls with user-visible error handling.
10. Build a focused automated test suite and CI workflow around subscription, reminders, SwiftData migration, medication-change state, and chart bucketing.
