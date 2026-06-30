import Foundation

/// Single source of truth for the calendar used in all date bucketing —
/// the Today date strip, Insights day/week/month buckets, and adherence-log
/// day normalization (M4).
///
/// Previously these used a mix of `Calendar(identifier: .iso8601)` with a
/// hardcoded Monday first-weekday (Today) and `Calendar.current` (Insights,
/// models). That risked the same data landing in different week buckets on
/// different screens or locales.
///
/// Policy: pin to the **Gregorian** identifier and the **current time zone**
/// for stable, predictable bucketing, while honoring the user's **locale
/// first-weekday** — so a US user gets Sunday-start weeks and, say, a German
/// user gets Monday-start weeks, each as they'd expect. For the common case
/// (a Gregorian device calendar) this is identical to `Calendar.current`, so
/// existing charts don't shift.
enum AppCalendar {
    static var current: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = .current
        calendar.firstWeekday = Calendar.current.firstWeekday
        return calendar
    }
}
