import Foundation
import SwiftData

/// Idempotent access to the single `MedAdherenceLog` for a calendar day (M3).
///
/// `MedAdherenceLog` is unique only by UUID, and two code paths create them —
/// the notification quick-actions (on their own background `ModelContext`) and
/// the daily check-in save (on the main context). Each does a find-or-create,
/// so they can race and produce duplicate logs for the same day, after which
/// reads become nondeterministic.
///
/// `upsert(for:in:)` is the single entry point: it returns one canonical log,
/// merging and deleting any same-day duplicates it finds. That makes it
/// self-healing — even pre-existing duplicates collapse the next time the day
/// is touched — without a schema change or a risky uniqueness migration.
enum AdherenceLogStore {

    /// Canonical adherence log for `date`'s calendar day. Merges + deletes any
    /// same-day duplicates; creates a fresh log if none exist.
    @discardableResult
    static func upsert(
        for date: Date,
        in context: ModelContext,
        calendar: Calendar = AppCalendar.current
    ) -> MedAdherenceLog {
        let day = calendar.startOfDay(for: date)
        let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<MedAdherenceLog>(
            predicate: #Predicate { $0.date >= day && $0.date < next }
        )
        // Deterministic canonical pick (UUID isn't Comparable for SortDescriptor).
        let existing = ((try? context.fetch(descriptor)) ?? [])
            .sorted { $0.id.uuidString < $1.id.uuidString }

        guard let canonical = existing.first else {
            let new = MedAdherenceLog(date: day)
            context.insert(new)
            return new
        }

        if existing.count > 1 {
            let dups = Array(existing.dropFirst())
            let resolved = merged(
                taken: [canonical.takenMedIDs] + dups.map(\.takenMedIDs),
                skipped: [canonical.skippedMedIDs] + dups.map(\.skippedMedIDs)
            )
            canonical.takenMedIDs = resolved.taken
            canonical.skippedMedIDs = resolved.skipped
            for dup in dups { context.delete(dup) }
        }
        return canonical
    }

    /// Pure merge of multiple logs' taken/skipped lists. Union of all taken;
    /// union of all skipped MINUS anything taken (a positive "took it"
    /// confirmation wins over a "skip", keeping the result consistent with
    /// `MedAdherenceLog.allTaken`'s disjointness expectation).
    static func merged(
        taken: [[UUID]],
        skipped: [[UUID]]
    ) -> (taken: [UUID], skipped: [UUID]) {
        let allTaken = taken.reduce(into: Set<UUID>()) { $0.formUnion($1) }
        var allSkipped = skipped.reduce(into: Set<UUID>()) { $0.formUnion($1) }
        allSkipped.subtract(allTaken)
        return (Array(allTaken), Array(allSkipped))
    }
}
