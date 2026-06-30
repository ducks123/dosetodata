import Foundation
import SwiftData

/// One record per calendar day capturing which scheduled medications were
/// taken and which were skipped. Created either via a notification quick-action
/// ("Took it" / "Skip today") or when the user submits their daily check-in.
@Model
final class MedAdherenceLog {
    var id: UUID
    /// Normalized to the start of the local calendar day.
    var date: Date
    /// UserMedication IDs the user confirmed taking.
    var takenMedIDs: [UUID]
    /// UserMedication IDs explicitly marked as skipped / not taken.
    var skippedMedIDs: [UUID]

    init(date: Date) {
        self.id = UUID()
        self.date = AppCalendar.current.startOfDay(for: date)
        self.takenMedIDs = []
        self.skippedMedIDs = []
    }

    /// True when every ID in `scheduledIDs` appears in `takenMedIDs` and none
    /// appear in `skippedMedIDs`. An empty schedule always returns true.
    func allTaken(scheduledIDs: Set<UUID>) -> Bool {
        guard !scheduledIDs.isEmpty else { return true }
        return scheduledIDs.isSubset(of: Set(takenMedIDs)) &&
               Set(skippedMedIDs).isDisjoint(with: scheduledIDs)
    }

    /// True when at least one ID in `scheduledIDs` was explicitly skipped.
    func anySkipped(scheduledIDs: Set<UUID>) -> Bool {
        !Set(skippedMedIDs).isDisjoint(with: scheduledIDs)
    }
}
