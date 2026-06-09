import Foundation

/// Windows + averages for a single `MedChangeEvent` so the marker-detail
/// sheet on Insights can show "before vs after" numbers.
///
/// **Window rules (per agreed spec):**
/// - Default window is 7 days before and 7 days after the event's date.
/// - **Adjacent-change cap:** when another `MedChangeEvent` sits inside
///   the 7-day window, the window is capped so it doesn't cross the
///   neighboring change. This preserves clean attribution at the cost of
///   smaller sample size (the UI shows the sample count as a caveat).
/// - The event's own day is excluded from both windows.
///
/// **Sample size bands (per agreed spec):**
/// - `0–1` check-in days in either window → `.none` ("Not enough data")
/// - `2–4`                                → `.small` (show + caveat copy)
/// - `5+`                                 → `.normal` (show + neutral footer)
///
/// The struct is pure Swift, no SwiftUI or SwiftData imports, so it's
/// easy to test and to invoke from anywhere.
struct MedChangeWindowAnalysis {

    // MARK: - Public types

    struct Window {
        /// Inclusive start (start-of-day).
        let start: Date
        /// Inclusive end (start-of-day).
        let end: Date
        /// Distinct check-in days that landed inside the window.
        let sampleSize: Int
        /// Total day count of the window (helps render "N of M days").
        let dayCount: Int
    }

    /// One row of the before-vs-after table — for a standard question OR
    /// the synthetic "overall" row.
    struct QuestionAverages: Identifiable {
        /// Stable id for the SwiftUI `ForEach`. Uses the question key.
        let id: String
        /// `questionKey` is either a `StandardCheckInQuestion.rawValue`
        /// (e.g. `"focus"`) or the synthetic key `"overall"`.
        let questionKey: String
        /// Display label for the row ("Focus", "Overall", etc.).
        let label: String
        let beforeMean: Double?
        let afterMean: Double?
    }

    enum SampleSizeBand {
        /// Hide the numbers entirely — copy reads "Not enough data."
        case none
        /// Show the numbers with the small-sample caveat copy.
        case small
        /// Show the numbers with a plain neutral footer.
        case normal
    }

    // MARK: - Inputs

    let event: AnalyzableEvent
    let neighborDates: [Date]   // dates of every other event, sorted
    let checkIns: [AnalyzableCheckIn]
    let calendar: Calendar

    // MARK: - Outputs (computed lazily)

    let beforeWindow: Window
    let afterWindow: Window
    let rows: [QuestionAverages]
    let sampleSizeBand: SampleSizeBand

    // MARK: - Init

    /// - Parameters:
    ///   - event: the change event under analysis.
    ///   - allEvents: every `MedChangeEvent` (including this one) so the
    ///     algorithm can find adjacent changes and cap the windows.
    ///   - checkIns: every `DailyCheckIn` (will be filtered to the windows
    ///     internally).
    ///   - calendar: defaults to the current calendar.
    init(
        event: AnalyzableEvent,
        allEvents: [AnalyzableEvent],
        checkIns: [AnalyzableCheckIn],
        calendar: Calendar = .current
    ) {
        self.event = event
        self.checkIns = checkIns
        self.calendar = calendar

        let eventDay = calendar.startOfDay(for: event.date)
        let neighborStartDays = allEvents
            .map { calendar.startOfDay(for: $0.date) }
            .filter { $0 != eventDay }
            .sorted()
        self.neighborDates = neighborStartDays

        // ── Compute windows ────────────────────────────────────────────
        let oneDay: TimeInterval = 86_400

        let defaultBeforeStart = calendar.date(byAdding: .day, value: -7, to: eventDay)
            ?? eventDay.addingTimeInterval(-7 * oneDay)
        let defaultBeforeEnd = calendar.date(byAdding: .day, value: -1, to: eventDay)
            ?? eventDay.addingTimeInterval(-oneDay)
        let defaultAfterStart = calendar.date(byAdding: .day, value: 1, to: eventDay)
            ?? eventDay.addingTimeInterval(oneDay)
        let defaultAfterEnd = calendar.date(byAdding: .day, value: 7, to: eventDay)
            ?? eventDay.addingTimeInterval(7 * oneDay)

        // The previous-event cap pulls the BEFORE window forward.
        let prevEventDay = neighborStartDays.last(where: { $0 < eventDay })
        let beforeStart: Date
        if let prev = prevEventDay {
            // Window can't include the previous event date or anything
            // before it (since that data was about a different change).
            // Cap at prev + 1 day.
            let prevPlusOne = calendar.date(byAdding: .day, value: 1, to: prev) ?? prev
            beforeStart = max(defaultBeforeStart, prevPlusOne)
        } else {
            beforeStart = defaultBeforeStart
        }
        let beforeEnd = defaultBeforeEnd

        // The next-event cap pulls the AFTER window in.
        let nextEventDay = neighborStartDays.first(where: { $0 > eventDay })
        let afterStart = defaultAfterStart
        let afterEnd: Date
        if let next = nextEventDay {
            let nextMinusOne = calendar.date(byAdding: .day, value: -1, to: next) ?? next
            afterEnd = min(defaultAfterEnd, nextMinusOne)
        } else {
            afterEnd = defaultAfterEnd
        }

        // ── Distinct check-in days per window ──────────────────────────
        func sampleSize(start: Date, end: Date) -> Int {
            guard start <= end else { return 0 }
            let daysInWindow = Set(
                checkIns
                    .map { calendar.startOfDay(for: $0.date) }
                    .filter { $0 >= start && $0 <= end }
            )
            return daysInWindow.count
        }

        func dayCount(start: Date, end: Date) -> Int {
            guard start <= end else { return 0 }
            let comps = calendar.dateComponents([.day], from: start, to: end)
            return (comps.day ?? 0) + 1   // inclusive
        }

        self.beforeWindow = Window(
            start: beforeStart,
            end: beforeEnd,
            sampleSize: sampleSize(start: beforeStart, end: beforeEnd),
            dayCount: dayCount(start: beforeStart, end: beforeEnd)
        )
        self.afterWindow = Window(
            start: afterStart,
            end: afterEnd,
            sampleSize: sampleSize(start: afterStart, end: afterEnd),
            dayCount: dayCount(start: afterStart, end: afterEnd)
        )

        // ── Per-question averages ──────────────────────────────────────
        // Standard active questions + a synthetic "overall" row computed
        // from each check-in's mean across its scale answers.
        let standardKeys = AnalyzableCheckIn.activeStandardKeys

        func mean(for keys: Set<String>, start: Date, end: Date) -> Double? {
            let inWindow = checkIns.filter { ci in
                let day = calendar.startOfDay(for: ci.date)
                return day >= start && day <= end
            }
            let values = inWindow.compactMap { ci -> Double? in
                let matched = ci.scaleAnswers.filter { keys.contains($0.questionKey) }
                guard !matched.isEmpty else { return nil }
                let sum = matched.map { Double($0.numericLevel) }.reduce(0, +)
                return sum / Double(matched.count)
            }
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }

        var builtRows: [QuestionAverages] = []
        // Overall row first.
        builtRows.append(
            QuestionAverages(
                id: "overall",
                questionKey: "overall",
                label: "Overall",
                beforeMean: mean(for: Set(standardKeys.map { $0.key }), start: beforeStart, end: beforeEnd),
                afterMean: mean(for: Set(standardKeys.map { $0.key }), start: afterStart, end: afterEnd)
            )
        )
        // Then each active standard question in declaration order.
        for q in standardKeys {
            builtRows.append(
                QuestionAverages(
                    id: q.key,
                    questionKey: q.key,
                    label: q.label,
                    beforeMean: mean(for: [q.key], start: beforeStart, end: beforeEnd),
                    afterMean: mean(for: [q.key], start: afterStart, end: afterEnd)
                )
            )
        }
        self.rows = builtRows

        // ── Sample-size band ───────────────────────────────────────────
        // Use the worse of the two windows so the warning is honest about
        // the weakest side of the comparison.
        let worstSample = min(beforeWindow.sampleSize, afterWindow.sampleSize)
        if worstSample <= 1 {
            self.sampleSizeBand = .none
        } else if worstSample <= 4 {
            self.sampleSizeBand = .small
        } else {
            self.sampleSizeBand = .normal
        }
    }
}

// MARK: - Lightweight protocols / DTOs
//
// The analyzer is intentionally decoupled from SwiftData. Callers convert
// their `MedChangeEvent` and `DailyCheckIn` records to these simple
// structs before passing them in. Keeps the analysis pure-Swift and
// testable.

struct AnalyzableEvent {
    let id: UUID
    let date: Date
}

struct AnalyzableScaleAnswer {
    let questionKey: String
    let numericLevel: Int
}

struct AnalyzableCheckIn {
    let date: Date
    let scaleAnswers: [AnalyzableScaleAnswer]

    /// Standard questions currently shown in the daily check-in form +
    /// their display labels. This is the source of truth for which rows
    /// appear in the before/after table. Excludes retired questions like
    /// `.anxiety` / `.irritability` (which we keep for historical data
    /// rendering but don't ask about going forward).
    static let activeStandardKeys: [(key: String, label: String)] = [
        ("focus", "Focus"),
        ("easeToStart", "Ease to start"),
        ("mood", "Emotional state"),
        ("energy", "Energy"),
        ("sleep", "Sleep"),
    ]
}
