import XCTest
import SwiftData
@testable import DoseToData

final class DoseToDataTests: XCTestCase {
    func testMedicationLibraryJSONDecodes() throws {
        let bundle = Bundle(for: Self.self)
        let appBundle = Bundle.allBundles.first { $0.url(forResource: "MedicationLibrary", withExtension: "json") != nil } ?? bundle
        guard let url = appBundle.url(forResource: "MedicationLibrary", withExtension: "json") else {
            XCTFail("MedicationLibrary.json not found in any loaded bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([MedicationSeeder.LibraryEntry].self, from: data)
        XCTAssertGreaterThanOrEqual(entries.count, 80, "Expected 80+ medication entries")
    }

    // MARK: - H1: write-access gating

    func testCanWriteForResolvedStatesIgnoresCache() {
        // Resolved states defer to the status's own canWrite, regardless of cache.
        XCTAssertTrue(SubscriptionService.effectiveCanWrite(status: .active, lastKnownCanWrite: false))
        XCTAssertTrue(SubscriptionService.effectiveCanWrite(status: .trial(daysLeft: 3), lastKnownCanWrite: false))
        XCTAssertFalse(SubscriptionService.effectiveCanWrite(status: .expired, lastKnownCanWrite: true))
    }

    func testLoadingUsesCachedValueAndClosesExpiredColdStartHole() {
        // The bug: .loading used to allow writes unconditionally. Now an
        // expired user (cached false) is blocked during the cold-start window…
        XCTAssertFalse(SubscriptionService.effectiveCanWrite(status: .loading, lastKnownCanWrite: false))
        // …while a previously-writable user (cached true) isn't blocked.
        XCTAssertTrue(SubscriptionService.effectiveCanWrite(status: .loading, lastKnownCanWrite: true))
    }

    func testLoadingWithNoCacheDefaultsToWritable() {
        // Fresh install mid-onboarding has no cached answer — must not be blocked.
        XCTAssertTrue(SubscriptionService.effectiveCanWrite(status: .loading, lastKnownCanWrite: nil))
    }

    // MARK: - H2: reminder identifier / clear contract

    func testReminderIdentifierMatchesClearPrefix() {
        // clearReminders(for:) removes requests whose id has this prefix, so
        // every scheduled identifier for a med MUST start with that prefix —
        // otherwise stop/delete would leak notifications.
        let id = UUID()
        let prefix = ReminderManager.reminderIdentifierPrefix(userMedID: id)
        let scheduled = ReminderManager.reminderIdentifier(userMedID: id, timeString: "08:00", weekday: 2)
        XCTAssertTrue(scheduled.hasPrefix(prefix),
                      "A scheduled reminder id must match the clear prefix, or stop/delete leaks it")
    }

    func testReminderPrefixDoesNotMatchOtherMedications() {
        // Clearing one med must not remove another med's reminders.
        let a = UUID()
        let b = UUID()
        let prefixA = ReminderManager.reminderIdentifierPrefix(userMedID: a)
        let scheduledB = ReminderManager.reminderIdentifier(userMedID: b, timeString: "08:00", weekday: 2)
        XCTAssertFalse(scheduledB.hasPrefix(prefixA),
                       "Clearing med A must not match med B's reminder ids")
    }

    func testReminderIdentifierIsUniquePerTimeAndWeekday() {
        let id = UUID()
        let monday8 = ReminderManager.reminderIdentifier(userMedID: id, timeString: "08:00", weekday: 2)
        let monday8pm = ReminderManager.reminderIdentifier(userMedID: id, timeString: "20:00", weekday: 2)
        let tuesday8 = ReminderManager.reminderIdentifier(userMedID: id, timeString: "08:00", weekday: 3)
        XCTAssertNotEqual(monday8, monday8pm)
        XCTAssertNotEqual(monday8, tuesday8)
    }

    // MARK: - H3: med-change marker bucketing stays inside the chart window

    /// Gregorian, Sunday-first, fixed timezone for deterministic boundary math.
    private var fixedCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.firstWeekday = 1
        return c
    }

    func testMarkerBucketsToSameDayAsNow_DayRange() {
        let cal = fixedCalendar
        // An event logged "today" at 2:30pm must bucket to the same day as the
        // window end ("now") so its marker lands on the rightmost gridline,
        // not past the domain. (This is the core C... H3 fix.)
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 9, minute: 0))!
        let eventToday = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 14, minute: 30))!
        XCTAssertEqual(
            InsightsView.bucketKey(for: eventToday, range: .day, calendar: cal),
            InsightsView.bucketKey(for: now, range: .day, calendar: cal)
        )
    }

    func testMarkerBucketsToSameWeekAsNow_WeekRange() {
        let cal = fixedCalendar
        // Sunday-first week of 2026-06-28 is Sun 6/28 … Sat 7/4.
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 8))!     // Sunday
        let midWeekEvent = cal.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 17))! // Wednesday
        XCTAssertEqual(
            InsightsView.bucketKey(for: midWeekEvent, range: .week, calendar: cal),
            InsightsView.bucketKey(for: now, range: .week, calendar: cal),
            "A change logged mid-current-week must share the current week's bucket"
        )
    }

    func testDifferentDaysProduceDifferentDayBuckets() {
        let cal = fixedCalendar
        let d1 = cal.date(from: DateComponents(year: 2026, month: 6, day: 27, hour: 23))!
        let d2 = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 1))!
        XCTAssertNotEqual(
            InsightsView.bucketKey(for: d1, range: .day, calendar: cal),
            InsightsView.bucketKey(for: d2, range: .day, calendar: cal)
        )
    }

    func testMarkerBucketIsAtStartOfBucket() {
        let cal = fixedCalendar
        let event = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 14, minute: 30))!
        let bucket = InsightsView.bucketKey(for: event, range: .day, calendar: cal)
        XCTAssertEqual(bucket, cal.startOfDay(for: event), "Day bucket must be midnight (start of bucket)")
    }

    // MARK: - H4: side effects saved against the selected check-in day

    func testSideEffectDateForPastDayUsesStartOfThatDay() {
        let cal = fixedCalendar
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 15))!
        let pastDay = cal.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 9))!
        let stamped = CheckInSideEffectReconciler.sideEffectDate(forTargetDate: pastDay, now: now, calendar: cal)
        // Must land on the target day, NOT today (the original bug).
        XCTAssertTrue(cal.isDate(stamped, inSameDayAs: pastDay))
        XCTAssertFalse(cal.isDate(stamped, inSameDayAs: now))
        XCTAssertEqual(stamped, cal.startOfDay(for: pastDay))
    }

    func testSideEffectDateForTodayUsesNow() {
        let cal = fixedCalendar
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 15))!
        let today = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 8))!
        let stamped = CheckInSideEffectReconciler.sideEffectDate(forTargetDate: today, now: now, calendar: cal)
        XCTAssertEqual(stamped, now)
    }

    func testReconcileDeletesOnlyRemovedExistingEntries() {
        let kept = UUID()
        let removed = UUID()
        let toDelete = CheckInSideEffectReconciler.idsToDelete(
            existingForDate: [kept, removed],
            keptExistingIDs: [kept]
        )
        XCTAssertEqual(toDelete, [removed], "Only the entry the user removed should be deleted")
    }

    func testReconcileDeletesNothingWhenAllKept() {
        let a = UUID(); let b = UUID()
        let toDelete = CheckInSideEffectReconciler.idsToDelete(
            existingForDate: [a, b],
            keptExistingIDs: [a, b]
        )
        XCTAssertTrue(toDelete.isEmpty, "Re-saving unchanged side effects must not delete (or duplicate) them")
    }

    // MARK: - M2: logged save helper

    func testSaveChangesReturnsTrueOnSuccess() throws {
        let schema = Schema([Medication.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        context.insert(Medication(
            brandName: "Test", genericName: "test", medClass: "Custom",
            commonDoses: [], commonSideEffects: [], isExtendedRelease: false, category: .other
        ))
        XCTAssertTrue(context.saveChanges("unit test"),
                      "saveChanges should persist and report success")
    }

    // MARK: - M3: adherence log dedupe / merge

    func testAdherenceMergedTakenWinsOverSkipped() {
        let med = UUID()
        let result = AdherenceLogStore.merged(taken: [[med]], skipped: [[med]])
        XCTAssertEqual(result.taken, [med])
        XCTAssertTrue(result.skipped.isEmpty, "An ID both taken and skipped must resolve to taken")
    }

    func testAdherenceMergedUnionsAcrossLogs() {
        let a = UUID(); let b = UUID(); let c = UUID()
        let result = AdherenceLogStore.merged(taken: [[a], [b]], skipped: [[c]])
        XCTAssertEqual(Set(result.taken), [a, b])
        XCTAssertEqual(Set(result.skipped), [c])
    }

    func testUpsertCollapsesDuplicateSameDayLogs() throws {
        let schema = Schema([MedAdherenceLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let day = Date()
        let medTaken = UUID(); let medSkipped = UUID()
        let log1 = MedAdherenceLog(date: day); log1.takenMedIDs = [medTaken]
        let log2 = MedAdherenceLog(date: day); log2.skippedMedIDs = [medSkipped]
        context.insert(log1); context.insert(log2)
        try context.save()

        let canonical = AdherenceLogStore.upsert(for: day, in: context)
        try context.save()

        let all = try context.fetch(FetchDescriptor<MedAdherenceLog>())
        XCTAssertEqual(all.count, 1, "Duplicate same-day logs must collapse to one")
        XCTAssertEqual(Set(canonical.takenMedIDs), [medTaken])
        XCTAssertEqual(Set(canonical.skippedMedIDs), [medSkipped])
    }

    func testUpsertCreatesWhenNoneExist() throws {
        let schema = Schema([MedAdherenceLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        _ = AdherenceLogStore.upsert(for: Date(), in: context)
        try context.save()

        let all = try context.fetch(FetchDescriptor<MedAdherenceLog>())
        XCTAssertEqual(all.count, 1)
    }

    // MARK: - M4: shared calendar policy

    func testAppCalendarPolicyIsStableAndLocaleAware() {
        let cal = AppCalendar.current
        // Pinned identifier + time zone for predictable bucketing…
        XCTAssertEqual(cal.identifier, .gregorian)
        XCTAssertEqual(cal.timeZone, TimeZone.current)
        // …but honors the locale's first weekday (no observable shift vs the
        // Insights charts' previous Calendar.current on Gregorian devices).
        XCTAssertEqual(cal.firstWeekday, Calendar.current.firstWeekday)
    }

    // MARK: - M5 (revised): future check-ins plot, but never move trend %

    func testFutureCheckInIsInScopeForPlotting() {
        let cal = fixedCalendar
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 15))!
        let start = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let tomorrow = cal.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 9))!
        // Logging ahead is a deliberate feature; the chart's trailing headroom
        // renders future points instead of clipping them invisible.
        XCTAssertTrue(InsightsView.isCheckInInScope(tomorrow, start: start, now: now, calendar: cal),
                      "A future-dated check-in must plot on the charts")
    }

    func testTrendSeriesDropsFutureBuckets() {
        let cal = fixedCalendar
        let todayBucket = cal.date(from: DateComponents(year: 2026, month: 6, day: 28))!
        let yesterday = cal.date(from: DateComponents(year: 2026, month: 6, day: 27))!
        let tomorrow = cal.date(from: DateComponents(year: 2026, month: 6, day: 29))!
        let points = [
            InsightsView.ChartPoint(date: yesterday, value: 3),
            InsightsView.ChartPoint(date: todayBucket, value: 4),
            InsightsView.ChartPoint(date: tomorrow, value: 5),
        ]
        let trend = InsightsView.trendSeries(points, todayBucket: todayBucket)
        // The future bucket plots on the chart but must not move the trend %.
        XCTAssertEqual(trend.map(\.value), [3, 4],
                       "Future buckets must be excluded from trend math (M5)")
    }

    func testTodayAndPastCheckInsAreInScope() {
        let cal = fixedCalendar
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 15))!
        let start = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        // Today, even later than `now`, is still in scope (whole day counts).
        let todayLater = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 23))!
        let pastDay = cal.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        XCTAssertTrue(InsightsView.isCheckInInScope(todayLater, start: start, now: now, calendar: cal))
        XCTAssertTrue(InsightsView.isCheckInInScope(pastDay, start: start, now: now, calendar: cal))
    }

    func testCheckInBeforeScopeStartIsExcluded() {
        let cal = fixedCalendar
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 15))!
        let start = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let beforeStart = cal.date(from: DateComponents(year: 2026, month: 5, day: 30))!
        XCTAssertFalse(InsightsView.isCheckInInScope(beforeStart, start: start, now: now, calendar: cal))
    }

    // MARK: - M6: trial days remaining uses exact expiry (no early expiry)

    func testTrialDaysRemainingDoesNotExpireWithTimeLeft() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        // 18 hours left — previously floored to 0 (expired early); must be >= 1.
        let expiry = now.addingTimeInterval(18 * 3600)
        XCTAssertEqual(SubscriptionService.trialDaysRemaining(expiry: expiry, now: now), 1)
    }

    func testTrialDaysRemainingZeroOnceExpired() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        XCTAssertEqual(SubscriptionService.trialDaysRemaining(expiry: now, now: now), 0)
        XCTAssertEqual(SubscriptionService.trialDaysRemaining(expiry: now.addingTimeInterval(-3600), now: now), 0)
    }

    func testTrialDaysRemainingCeilsPartialDays() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        XCTAssertEqual(SubscriptionService.trialDaysRemaining(expiry: now.addingTimeInterval(14 * 86_400), now: now), 14)
        // 13.2 days left rounds up to 14, never under-counts.
        XCTAssertEqual(SubscriptionService.trialDaysRemaining(expiry: now.addingTimeInterval(13.2 * 86_400), now: now), 14)
        // 1 second left still shows a day, not expired.
        XCTAssertEqual(SubscriptionService.trialDaysRemaining(expiry: now.addingTimeInterval(1), now: now), 1)
    }

    // MARK: - M8: streak logic

    func testStreakEmptyIsZero() {
        XCTAssertEqual(AppState.currentStreak(from: []), 0)
    }

    func testStreakSingleTodayIsOne() {
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(AppState.currentStreak(from: [today]), 1)
    }

    func testStreakCountsConsecutiveDays() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let twoAgo = cal.date(byAdding: .day, value: -2, to: today)!
        XCTAssertEqual(AppState.currentStreak(from: [twoAgo, yesterday, today]), 3)
    }

    func testStreakBreaksOnGap() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let twoAgo = cal.date(byAdding: .day, value: -2, to: today)!  // yesterday missing
        XCTAssertEqual(AppState.currentStreak(from: [twoAgo, today]), 1)
    }

    func testStreakZeroWhenMostRecentIsStale() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let threeAgo = cal.date(byAdding: .day, value: -3, to: today)!
        let fourAgo = cal.date(byAdding: .day, value: -4, to: today)!
        // Latest check-in is 3 days ago (not today/yesterday) → streak broken.
        XCTAssertEqual(AppState.currentStreak(from: [fourAgo, threeAgo]), 0)
    }

    // MARK: - M8: medication-change action summary copy

    private func med(_ brand: String) -> Medication {
        Medication(brandName: brand, genericName: "generic", medClass: "Custom",
                   commonDoses: [], commonSideEffects: [], isExtendedRelease: false, category: .other)
    }

    func testMedActionSummaryStart() {
        let action = MedAction(medication: med("Adderall"), kind: .start, dose: "10mg")
        XCTAssertEqual(action.summaryLine, "Adderall + Started 10mg")
    }

    func testMedActionSummaryStartWithoutDose() {
        let action = MedAction(medication: med("Adderall"), kind: .start)
        XCTAssertEqual(action.summaryLine, "Adderall + Started")
    }

    func testMedActionSummaryStop() {
        let action = MedAction(medication: med("Lexapro"), kind: .stop)
        XCTAssertEqual(action.summaryLine, "Lexapro \u{2212} Stopped")
    }

    func testMedActionSummaryDoseChange() {
        let action = MedAction(medication: med("Wellbutrin"), kind: .doseChange, dose: "150mg", previousDose: "300mg")
        XCTAssertEqual(action.summaryLine, "Wellbutrin ↕ 300mg → 150mg")
    }
}

// MARK: - Paywall savings badge math

final class SavingsPercentTests: XCTestCase {
    func testStandardPricing() {
        // $4.99/mo * 12 = $59.88 vs $39.99/yr → 33% savings.
        // Regression: Int(truncating:) on the raw NSDecimalNumber quotient
        // overflowed and returned 0, silently hiding the SAVE badge.
        XCTAssertEqual(
            PaywallView.savingsPercent(monthlyPrice: Decimal(string: "4.99")!,
                                       annualPrice: Decimal(string: "39.99")!),
            33
        )
    }

    func testAnnualMoreExpensiveThanMonthlyIsZero() {
        XCTAssertEqual(
            PaywallView.savingsPercent(monthlyPrice: Decimal(string: "1.00")!,
                                       annualPrice: Decimal(string: "20.00")!),
            0
        )
    }

    func testZeroMonthlyPriceIsZero() {
        XCTAssertEqual(
            PaywallView.savingsPercent(monthlyPrice: 0,
                                       annualPrice: Decimal(string: "39.99")!),
            0
        )
    }

    func testExactIntegerSavings() {
        // $2/mo * 12 = $24 vs $12/yr → exactly 50%.
        XCTAssertEqual(
            PaywallView.savingsPercent(monthlyPrice: Decimal(string: "2.00")!,
                                       annualPrice: Decimal(string: "12.00")!),
            50
        )
    }
}
