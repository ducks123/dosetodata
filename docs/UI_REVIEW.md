# DoseToData UI/UX, Workflow, and Conversion Review

Review date: June 30, 2026

Scope: focused product-quality review of the iOS app as a local-first personal tracking tool for mood, medications, adherence, side effects, and medication changes. This is not a clinical, HIPAA, security, or medical-device audit.

## Testing Performed

- Reviewed SwiftUI source for onboarding, Today, Schedule, Insights, paywall, settings, reminders, medication changes, check-ins, and chart behavior.
- Built the app successfully with `xcodebuild build -project DoseToData.xcodeproj -scheme DoseToData -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -derivedDataPath /private/tmp/DoseToDataDerived -skipPackagePluginValidation`.
- Launched on iPhone 17 simulator running iOS 26.2.
- Visually verified the true first-run goals screen after clearing app defaults.
- Visually verified the main Today empty state on iPhone 17 simulator, iOS 26.2.
- Did not make a real purchase. Sandbox purchase validation was not completed.
- Deeper tap automation was blocked because macOS Accessibility access for `osascript`/desktop clicking was denied, so most multi-step findings are source-backed with manual reproduction steps.

## Overall Read

DoseToData has a strong base: calm visual style, clear daily check-in affordance, useful med-change tracking direction, and good work removing dose suggestions from medication add flows. The largest product risks are not HIPAA/security risks. They are activation, trust, and data-usefulness risks:

- The first-run flow asks for data before clearly explaining the product promise and local-first privacy model.
- The non-dismissible onboarding paywall can ask for payment before users have experienced graphs or value.
- Account/sign-in copy conflicts with the local-device positioning.
- Several data-entry flows allow ambiguous or incomplete medication-change data.
- Some graph/schedule affordances imply stronger clinical certainty or causality than the product should imply.

## Findings

### 1. Medium - First-run onboarding does not clearly state the product promise

- Severity: Medium.
- Area / screen: first-run onboarding, goals screen.
- Device and OS tested: iPhone 17 simulator, iOS 26.2.
- Steps to reproduce:
  1. Install fresh build.
  2. Clear app defaults or launch on a clean simulator.
  3. Open DoseToData.
  4. View the first screen.
- Expected behavior: The first screen should immediately explain that DoseToData helps users track mood, medications, side effects, adherence, and changes so they can notice patterns and bring context to a clinician, with data kept local-first.
- Actual behavior: The screen says "What do you want to track?" with category choices and "Pick anything that matters." It does not explain the outcome, clinician context, local-first trust, or non-advice positioning.
- Why it matters: Users are asked to commit before understanding why the app is valuable.
- Conversion, trust, or usefulness impact: Medium activation risk. The first screen feels like a generic tracker instead of a differentiated tool worth paying for.
- Recommended fix: Add concise value copy before the goal choices, for example: "Track daily check-ins, medications, side effects, and changes so patterns are easier to review later. Your data stays on this device." Keep this calm and non-clinical.
- Estimated difficulty: Small.

### 2. High - Privacy and non-medical-advice positioning appears after medication entry

- Severity: High.
- Area / screen: first-run onboarding, medication step and disclaimer step.
- Device and OS tested: iPhone 17 simulator, iOS 26.2 for first-run start; source-backed for flow order.
- Steps to reproduce:
  1. Fresh install.
  2. Select a tracking goal.
  3. Continue to "Any medications you're taking now?"
  4. Add or skip medication.
  5. Continue to the disclaimer screen.
- Expected behavior: Before asking for medication data, the app should set expectations: local-first, personal tracking, not diagnosis, not medication or dose recommendations, and useful for clinician conversations.
- Actual behavior: The disclaimer appears after the app has already asked for medications.
- Why it matters: Medication names and doses are sensitive. Asking for them before explaining local-first storage and product boundaries creates avoidable trust friction.
- Conversion, trust, or usefulness impact: High trust impact. Users may bounce or withhold useful data.
- Recommended fix: Move a short privacy/purpose card to the first screen or before medication entry. Keep the fuller disclaimer where it is if needed, but do not wait until after medication entry to establish trust.
- Estimated difficulty: Small to medium.

### 3. Critical - Onboarding paywall can block entry before users see app value

- Severity: Critical.
- Area / screen: onboarding paywall.
- Device and OS tested: source-backed; purchase not tested.
- Steps to reproduce:
  1. Fresh install.
  2. Complete goal selection, medication step, and disclaimer.
  3. Arrive at `PaywallView(isDismissible: false, onComplete: finish)`.
  4. If App Store/RevenueCat packages fail to load, observe the disabled purchase CTA and no close button.
- Expected behavior: Users should be able to experience enough value to understand why they would pay, or the app should gracefully enter a local trial/demo state when pricing cannot load.
- Actual behavior: The onboarding paywall is non-dismissible. `onComplete` only runs after purchase/silent restore acknowledgement. If packages do not load, CTA is disabled and first-run onboarding cannot complete.
- Why it matters: A first-run hard stop before any logged data or graph value is a major activation and conversion risk.
- Conversion, trust, or usefulness impact: Critical conversion impact when pricing fails; high conversion impact even when pricing succeeds because value is not demonstrated first.
- Recommended fix: Decide intentionally between "trial after App Store confirmation" and "local-first trial before paywall." If using a paywall in onboarding, add robust fallback for package failure and consider allowing users into a limited local trial so they can see Today, Schedule, and sample/empty Insights before paid intent.
- Estimated difficulty: Medium.

### 4. Medium - Paywall language feels broader and more clinical than the product purpose

- Severity: Medium.
- Area / screen: paywall.
- Device and OS tested: source-backed; visual purchase flow not completed.
- Steps to reproduce:
  1. Reach the paywall.
  2. Read the header and feature list.
  3. Note "Track your health, understand your data" and "Run custom tracking tests."
- Expected behavior: Paywall should sell personal tracking and pattern review without sounding like experimentation, treatment optimization, or clinical certainty.
- Actual behavior: "Health" is broad, and "custom tracking tests" sounds more clinical/experimental than a calm tracking app.
- Why it matters: The user explicitly wants to avoid diagnosis/treatment/recommendation framing.
- Conversion, trust, or usefulness impact: Medium trust impact. It may also trigger App Review concern if paired with medication changes.
- Recommended fix: Replace with language such as "Track daily patterns privately" and "Custom questions for what matters to you." Avoid "test" unless reframed as "tracking window" or "personal notes around changes."
- Estimated difficulty: Small.

### 5. High - Account/sign-in copy conflicts with local-device messaging

- Severity: High.
- Area / screen: Settings, AuthSheet, account deletion.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Open the app after onboarding.
  2. Tap Settings.
  3. Read the top data notice: "Your data is stored on this device only."
  4. Tap Sign in.
  5. Read the sheet title "Back up & sync" and success copy "Sync is on. Your data will back up automatically."
  6. Review delete-account dialog copy mentioning "synced data from our servers."
- Expected behavior: Account copy should clearly explain what is local, what is synced, and what sign-in is for.
- Actual behavior: Settings says data is device-only, while sign-in says backup/sync is on.
- Why it matters: Users cannot tell whether sensitive tracking data is local-only, backed up, synced, or partially synced.
- Conversion, trust, or usefulness impact: High trust impact. This is likely to stop privacy-sensitive users from subscribing.
- Recommended fix: Choose one product truth. If data is local-only, rename the sheet to "Account" or "Sign in" and remove backup/sync claims. If sync exists, explicitly say what syncs, what remains local, and whether deleting the app erases local history.
- Estimated difficulty: Small for copy; medium if behavior must change.

### 6. Medium - Medication reminder permission can appear too early

- Severity: Medium.
- Area / screen: onboarding add medication, Schedule add medication.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Add a medication.
  2. Enter a dose.
  3. Choose a schedule preset such as "Once daily - 8am."
  4. Tap "Add to my medications."
  5. Observe that reminders are enabled by default and notification authorization is requested when scheduling.
- Expected behavior: Users should explicitly opt into reminders after understanding what notifications will do.
- Actual behavior: Adding a scheduled med can immediately request notification permission because `remindersEnabled` defaults on and `scheduleReminders` calls authorization.
- Why it matters: Push-permission prompts before trust is established often reduce opt-in and can feel invasive.
- Conversion, trust, or usefulness impact: Medium trust and retention impact.
- Recommended fix: Add a reminder opt-in step or pre-permission explanation: "Want DoseToData to remind you at these times?" Default to off until the user chooses reminders.
- Estimated difficulty: Medium.

### 7. Medium - Add medication can save a schedule with no times

- Severity: Medium.
- Area / screen: Schedule tab, Add medication.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Open Schedule.
  2. Tap Add medication.
  3. Pick a library medication.
  4. Enter a dose.
  5. Leave "Add it to my medication schedule" on.
  6. Do not choose a time preset or custom time.
  7. Tap "Add to my medications."
- Expected behavior: If schedule is on, at least one time should be required, or the toggle should be off by default.
- Actual behavior: The medication is added with no scheduled times, later appearing as "Tap to set times" or "no times set."
- Why it matters: A user thinks they added a schedule, but the app has no times and no reminders.
- Conversion, trust, or usefulness impact: Medium usefulness impact. It weakens confidence in reminders and schedule accuracy.
- Recommended fix: Require at least one time while "Add to schedule" is enabled, or rename the toggle to "Track this medication" and make scheduling a separate explicit step.
- Estimated difficulty: Small to medium.

### 8. High - Check-ins cannot save adherence, side effects, or notes alone

- Severity: High.
- Area / screen: Today tab, DailyCheckInSheet.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Add a scheduled medication.
  2. Open Today's check-in.
  3. Mark a medication as "Didn't take," or add a side effect, or type a note.
  4. Do not answer any 1-5 scale question.
  5. Look at the bottom "Complete check-in" button.
- Expected behavior: The app should let users save any useful tracking data, including adherence-only, side-effect-only, or note-only entries.
- Actual behavior: The save button remains disabled because `hasAnyAnswer` only checks scale answers and custom text answers, not side effects, adherence, or the general note.
- Why it matters: Users may have exactly one important thing to record and cannot save it.
- Conversion, trust, or usefulness impact: High usefulness and retention impact. It discourages quick logging.
- Recommended fix: Count skipped/taken med changes, side effects, and non-empty note as valid check-in content. If a scale answer is required, explain that requirement clearly.
- Estimated difficulty: Small.

### 9. High - Check-in saves scheduled meds as taken by default

- Severity: High.
- Area / screen: Today tab, DailyCheckInSheet and CheckInDetailView.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Add a scheduled medication.
  2. Open Today's check-in.
  3. Answer one 1-5 question.
  4. Do not interact with the medication status section.
  5. Save the check-in.
  6. View the check-in detail.
- Expected behavior: The app should either require explicit adherence confirmation or visibly state that scheduled meds are assumed taken unless marked skipped.
- Actual behavior: `skippedMedIDs` starts empty, so saving writes all scheduled meds into `takenMedIDs`.
- Why it matters: Adherence data can look cleaner than reality if users do not notice the med section.
- Conversion, trust, or usefulness impact: High data-trust impact. Bad adherence data makes graphs less useful.
- Recommended fix: Add an explicit "Confirm meds" affordance, an "Unknown" default state, or clear copy: "Assumed taken unless you mark missed." Prefer explicit taken/skipped/unknown for each scheduled med.
- Estimated difficulty: Medium.

### 10. Medium - Past-day logging still says "today"

- Severity: Medium.
- Area / screen: Today tab, DailyCheckInSheet for past dates.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. On Today, select a past date in the date strip.
  2. Tap "Log for this day."
  3. View section labels in the check-in sheet.
- Expected behavior: Labels should use date-neutral language such as "Medications on this day" and "Side effects on this day."
- Actual behavior: The sheet uses "Medications today" and "Side effects today" even when logging a past date.
- Why it matters: Date accuracy is central to trust in a tracker.
- Conversion, trust, or usefulness impact: Medium usefulness and polish impact.
- Recommended fix: Use `isToday` to switch copy for medication and side-effect headings.
- Estimated difficulty: Small.

### 11. Medium - Future-day logging is allowed

- Severity: Medium.
- Area / screen: Today tab, date strip, DailyCheckInSheet.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. On Today, scroll the date strip to tomorrow or a later date.
  2. Tap the future date.
  3. Tap "Log for this day."
  4. Complete a check-in.
- Expected behavior: Users should not be able to log future mood, side effects, or adherence unless the app is explicitly collecting plans.
- Actual behavior: The date strip includes 365 future days and the check-in sheet can save future-dated check-ins.
- Why it matters: Future logs can corrupt habits, streaks, and graph interpretation.
- Conversion, trust, or usefulness impact: Medium data-trust impact.
- Recommended fix: Disable future check-ins or use a separate "planned reminder" model that does not count as actual tracking data.
- Estimated difficulty: Medium.

### 12. Medium - Custom check-in reminder time can be saved unintentionally

- Severity: Medium.
- Area / screen: Today tab, Check-in reminders.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Tap the bell icon on Today's check-in card.
  2. Tap "Add custom time."
  3. Do not tap "Add this time."
  4. Tap Done.
- Expected behavior: The custom time should only save if the user taps "Add this time."
- Actual behavior: `save()` auto-adds the wheel's current time when the custom picker is open.
- Why it matters: Users can accidentally schedule reminders they did not choose.
- Conversion, trust, or usefulness impact: Medium trust impact.
- Recommended fix: Remove the auto-commit behavior, or change Done to "Add and Save" only when the picker is open.
- Estimated difficulty: Small.

### 13. Medium - Recent changes empty copy implies causality

- Severity: Medium.
- Area / screen: Today tab, Recent changes empty state.
- Device and OS tested: iPhone 17 simulator, iOS 26.2.
- Steps to reproduce:
  1. Enter the app with no medication changes.
  2. Open Today.
  3. Read the Recent changes empty state.
- Expected behavior: Copy should say changes can be viewed alongside trends without implying the medication is affecting the trend.
- Actual behavior: The empty state says, "Log your first medication change so your chart shows what's affecting your trends."
- Why it matters: "Affecting" implies causality that the app cannot determine.
- Conversion, trust, or usefulness impact: Medium trust impact and possible App Review/product-positioning risk.
- Recommended fix: Use wording like "so your charts can show medication changes alongside your trends."
- Estimated difficulty: Small.

### 14. High - Schedule "Peak" effect bands imply clinical certainty

- Severity: High.
- Area / screen: Schedule tab timeline.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Add a medication that has a hard-coded PK profile, such as Adderall IR, Vyvanse, Ritalin IR, Concerta, Xanax, Ambien, or similar.
  2. Add a scheduled time.
  3. Open Schedule.
  4. View the timeline.
- Expected behavior: Schedule should show user-entered dose times and reminders. If any reference timing appears, it should be clearly framed as optional general reference and not individualized prediction.
- Actual behavior: The Schedule timeline renders an effect curve and a "Peak" label using hard-coded pharmacokinetic profiles.
- Why it matters: This can look like the app is predicting medication effect windows or advising around dose timing.
- Conversion, trust, or usefulness impact: High trust/product-positioning impact. It may make the app feel more clinical than intended.
- Recommended fix: Remove PK effect bands from the default Schedule view, or make them opt-in with explicit "general reference, not medical advice, not individualized" language. A safer default is a plain reminder timeline.
- Estimated difficulty: Medium.

### 15. High - Stopping a medication from Schedule does not create the current medication-change timeline event

- Severity: High.
- Area / screen: Schedule tab, Edit medications.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Add a medication.
  2. Open Schedule.
  3. Tap "Edit list."
  4. Tap the stop/remove icon.
  5. Confirm "Stop medication."
  6. Go to Today Recent changes and Insights markers.
- Expected behavior: Stopping/removing a medication should create the same kind of medication-change record shown in Recent changes and Insights, and should let the user set the actual stop date.
- Actual behavior: The stop flow sets `endDate = Date()` and inserts legacy `MedEvent`, while Today/Insights use `MedChangeEvent`. This can hide the stop from current chart markers and recent changes.
- Why it matters: Medication changes are one of the core values of the app. Losing them in one management path breaks the story users want to bring to clinicians.
- Conversion, trust, or usefulness impact: High usefulness impact.
- Recommended fix: Make Schedule stop/remove route through the current `MedChangeEvent` model or clearly send users to "Log medication change" for starts/stops/dose changes. Let users choose the effective date.
- Estimated difficulty: Medium.

### 16. High - Medication-change logging can save incomplete dose changes

- Severity: High.
- Area / screen: Today tab, Log medication change.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Tap "Log a medication change."
  2. Tap "Choose a medication."
  3. Pick a medication.
  4. Leave action as Start with the dose blank, or choose Dose change with previous/new doses blank.
  5. Tap "Save medication change."
- Expected behavior: Start and dose-change flows should require the fields needed to make the record useful, or explicitly mark the dose as unknown.
- Actual behavior: `canSave` only requires a medication. Start can create an active `UserMedication` with an empty `currentDose`; dose changes can save as generic "Dose change" without a new dose.
- Why it matters: Ambiguous medication-change data makes charts and clinician conversations less useful.
- Conversion, trust, or usefulness impact: High data-usefulness impact.
- Recommended fix: Require dose for Start and new dose for Dose change, with an explicit "I don't know / not sure" option if needed. Show validation inline before enabling Save.
- Estimated difficulty: Small to medium.

### 17. Medium - Insights trends lack data-quality context

- Severity: Medium.
- Area / screen: Insights charts.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Log two check-ins with different answered question sets.
  2. Open Insights.
  3. View "Overall score" and trend badges.
- Expected behavior: Charts should explain what the score represents, how many entries are included, and that higher means better because of the scale convention.
- Actual behavior: Overall score averages whatever scale answers exist in each bucket. Trend badges show percent changes without sample size or completeness context.
- Why it matters: A change can reflect a different question mix rather than an actual pattern.
- Conversion, trust, or usefulness impact: Medium graph-trust impact.
- Recommended fix: Add small context lines such as "Based on 4 check-ins" and "1 = harder, 5 = better." Consider showing data completeness or only comparing like-for-like answered questions.
- Estimated difficulty: Medium.

### 18. Medium - Chart marker and selection behavior loses important detail

- Severity: Medium.
- Area / screen: Insights charts, Day/Week/Month/Year switching.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Log several check-ins and medication changes.
  2. Open Insights.
  3. Switch between Day, Week, Month, and Year.
  4. Tap chart points and marker chips.
- Expected behavior: Users should be able to understand which medication change is near a trend and inspect relevant check-ins in every range.
- Actual behavior: Medication-change chips show date only, not the change summary. Markers are hidden entirely in Month and Year. Chart "View check-in" only finds a check-in when the aggregate bucket date matches a check-in day, which is weak for week/month/year buckets.
- Why it matters: Graphs are a primary paid-value surface. Users need to trust and understand what they are seeing.
- Conversion, trust, or usefulness impact: Medium usefulness and paid-conversion impact.
- Recommended fix: Add marker summaries, aggregate marker rows for Month/Year, and a bucket detail sheet listing check-ins and changes included in the selected bucket.
- Estimated difficulty: Medium to large.

### 19. Low - Insights empty state lacks a direct action

- Severity: Low.
- Area / screen: Insights empty state.
- Device and OS tested: source-backed.
- Steps to reproduce:
  1. Enter the app with no check-ins.
  2. Tap Insights.
  3. Read the empty state.
- Expected behavior: Empty state should include a direct "Start today's check-in" action or route to Today.
- Actual behavior: It tells the user to complete a check-in on Today but does not provide a CTA.
- Why it matters: Empty states are activation moments.
- Conversion, trust, or usefulness impact: Low to medium activation impact.
- Recommended fix: Add a primary button that switches to Today and opens the check-in sheet when write access allows.
- Estimated difficulty: Small.

### 20. Medium - Restore purchases can fail silently

- Severity: Medium.
- Area / screen: Paywall and Settings subscription section.
- Device and OS tested: source-backed; sandbox restore not tested.
- Steps to reproduce:
  1. Open the paywall or Settings.
  2. Tap "Restore purchases" with an Apple ID that has no active entitlement or when restore fails.
  3. Observe feedback.
- Expected behavior: User should receive clear feedback: restored, no purchases found, or unable to restore.
- Actual behavior: Calls use `try? await sub.restorePurchases()` in some places, which can swallow errors and provide no visible result.
- Why it matters: Restore is a trust and App Store expectation path.
- Conversion, trust, or usefulness impact: Medium trust and subscription-support impact.
- Recommended fix: Show success, no-entitlement, and failure states after restore attempts.
- Estimated difficulty: Small.

## Top 10 UI/UX Improvements Most Likely To Improve Activation, Retention, And Paid Conversion

1. Rewrite the first screen to explain the product promise, local-first trust, and clinician-conversation value before asking for goals.
2. Move privacy and non-advice positioning before medication entry.
3. Let users experience Today/Schedule/Insights value before the hard paywall, or make the onboarding paywall failure-proof.
4. Align account/sign-in copy with the local-first product truth.
5. Replace "custom tracking tests" and other clinical/experimental language with "custom questions" or "tracking windows."
6. Add direct CTAs from empty states, especially Insights to Today's check-in.
7. Make reminders explicitly opt-in with a pre-permission explanation.
8. Add clearer check-in completion feedback: streak, next useful action, and "see your trend" after enough data.
9. Improve medication-change flows so "log change" and "manage schedule" feel connected but distinct.
10. Add clear restore/manage subscription feedback and sandbox-validated subscription states.

## Top 10 Data/Graph Improvements Most Likely To Make The App More Useful

1. Allow check-ins to save adherence-only, side-effect-only, and note-only entries.
2. Stop defaulting medications to taken without explicit confirmation or clear copy.
3. Remove or heavily qualify PK "Peak" effect bands from Schedule.
4. Require meaningful dose/change fields in medication-change logging, or support explicit "unknown."
5. Use `MedChangeEvent` as the single source of truth for all starts, stops, and dose changes.
6. Disable future check-ins or store them separately as plans.
7. Add graph context: sample size, date range, and "1 harder, 5 better."
8. Add data completeness indicators so users know when a trend is thin or based on inconsistent questions.
9. Make chart marker chips include medication-change summaries, not just dates.
10. Add side effect and adherence layers to Insights so users can compare symptoms, missed meds, and changes without implying causality.

## Happy Path Manual Test Script Before Each App Store Release

1. Install a clean build on iPhone and one smaller device size if available.
2. Launch fresh and verify the first screen explains purpose, local-first data, and non-advice boundaries.
3. Select goals: Mood, Medications, Side effects.
4. Add a medication from the library with user-typed dose and one scheduled time.
5. Verify notification permission copy appears only after explicit reminder intent.
6. Accept the disclaimer.
7. Reach the paywall and verify price, trial, cancel, restore, privacy, and terms copy. Do not use a production purchase.
8. If using sandbox, start a sandbox trial and verify entry into the app.
9. On Today, complete a check-in with several scores, a side effect, one skipped medication, and a note.
10. View the saved check-in, then edit it and verify side effects/adherence are not duplicated.
11. Select yesterday and log a past-day check-in; verify all labels use past-day language.
12. Log a medication change with date, kind, dose fields, and "watching for" note.
13. Open Schedule, edit medication days/times, toggle reminders, and stop a medication with an effective date.
14. Open Insights, switch Day/Week/Month/Year, tap chart points, inspect marker chips, and verify no clinical conclusion is implied.
15. Open Settings, verify local-data copy, subscription status, restore/manage links, support, privacy policy, and terms.

## Conversion Path Manual Test Script From First Launch To Paid Intent

1. Fresh install on a clean simulator/device.
2. On first screen, confirm the user can answer: "What does this app do for me?" and "Where is my data?"
3. Continue through goals and medication entry without adding a medication; verify skipping feels safe and not like failure.
4. Repeat with adding a medication; verify dose entry never suggests a dose.
5. Confirm disclaimer reinforces: personal tracking, local-first, not diagnosis, not treatment or dose advice.
6. Reach the paywall and verify the user has seen enough value to understand why Premium matters.
7. Verify price is prominent, trial duration comes from App Store products, cancel language is clear, and restore has feedback.
8. In sandbox only, start a trial and verify the app enters a useful first session.
9. Complete first check-in and verify immediate reward plus a clear next step: keep tracking, add med change, or review Insights after more data.
10. Return to paywall from trial banner or locked state and verify the upgrade ask feels connected to value already experienced.

## Workflows Not Fully Tested And Why

- Real purchases and subscription renewals: not tested because no real purchases should be made; sandbox purchase testing still needs a sandbox Apple ID and StoreKit/RevenueCat validation.
- Full tap-through UI automation: simulator launched successfully, but desktop click automation was blocked by macOS Accessibility permissions.
- Notification delivery and notification quick actions: source reviewed, but scheduled notification timing and lock-screen actions were not exercised.
- Real account sign-in: not tested because it requires external auth/network interaction and credentials.
- Support/privacy/terms web links: source reviewed, but external web pages were not opened in this pass.
- Multi-day graph rendering with large real datasets: source reviewed; manual seed data or a dedicated UI test fixture would be needed for full visual validation.
- iPad layouts and smaller/older iPhone layouts: not tested in simulator during this pass.
- Dynamic Type, VoiceOver, Reduce Motion, and high-contrast accessibility modes: not tested; these should be added to release QA because the app uses large typography and dense chart surfaces.
