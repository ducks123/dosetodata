import Foundation

/// Pure helpers for saving side effects against the correct check-in day and
/// reconciling them on edit (H4). Kept free of SwiftData/SwiftUI so the date
/// and keep/delete logic is unit-testable.
enum CheckInSideEffectReconciler {

    /// The date a side effect should be stamped with for the day being edited.
    /// For today we keep the real `now` (so ordering within today is natural);
    /// for any other day we use the start of that day. This is the fix for
    /// side effects previously always defaulting to `Date()` — which recorded
    /// them on today even when editing a past check-in.
    static func sideEffectDate(forTargetDate targetDate: Date, now: Date, calendar: Calendar) -> Date {
        calendar.isDate(targetDate, inSameDayAs: now)
            ? now
            : calendar.startOfDay(for: targetDate)
    }

    /// Existing side-effect entry ids that should be deleted on save: those for
    /// the day that the user removed from the editing list (i.e. not in
    /// `keptExistingIDs`). Prevents duplicate rows on re-edit and makes removal
    /// actually stick.
    static func idsToDelete(existingForDate: [UUID], keptExistingIDs: Set<UUID>) -> [UUID] {
        existingForDate.filter { !keptExistingIDs.contains($0) }
    }
}
