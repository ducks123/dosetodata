import Foundation
import SwiftData

private struct MedicationTakenTimestamp: Codable {
    let medicationID: UUID
    let takenAt: Date
}

/// One record per calendar day capturing which scheduled medications were
/// taken and which were skipped. Created either via a notification quick-action
/// ("Taken" / "Skip today") or when the user submits their daily check-in.
@Model
final class MedAdherenceLog {
    var id: UUID
    /// Normalized to the start of the local calendar day.
    var date: Date
    /// UserMedication IDs the user confirmed taking.
    var takenMedIDs: [UUID]
    /// UserMedication IDs explicitly marked as skipped / not taken.
    var skippedMedIDs: [UUID]
    /// JSON-encoded timestamps keyed by UserMedication ID. Optional so the
    /// property can migrate safely onto existing adherence records; older
    /// "Taken" entries remain valid but correctly show no invented time.
    var takenAtData: Data?

    init(date: Date) {
        self.id = UUID()
        self.date = AppCalendar.current.startOfDay(for: date)
        self.takenMedIDs = []
        self.skippedMedIDs = []
        self.takenAtData = nil
    }

    var takenAtByMedicationID: [UUID: Date] {
        guard let takenAtData,
              let records = try? JSONDecoder().decode(
                [MedicationTakenTimestamp].self,
                from: takenAtData
              )
        else { return [:] }

        return records.reduce(into: [:]) { result, record in
            if let existing = result[record.medicationID] {
                result[record.medicationID] = max(existing, record.takenAt)
            } else {
                result[record.medicationID] = record.takenAt
            }
        }
    }

    func takenAt(for medicationID: UUID) -> Date? {
        takenAtByMedicationID[medicationID]
    }

    func recordTaken(_ medicationIDs: [UUID], at timestamp: Date) {
        var timestamps = takenAtByMedicationID
        for medicationID in medicationIDs {
            timestamps[medicationID] = timestamp
        }
        replaceTakenTimestamps(timestamps)
    }

    func clearTakenTimestamp(for medicationID: UUID) {
        var timestamps = takenAtByMedicationID
        timestamps.removeValue(forKey: medicationID)
        replaceTakenTimestamps(timestamps)
    }

    func replaceTakenTimestamps(_ timestamps: [UUID: Date]) {
        let records = timestamps
            .map { MedicationTakenTimestamp(medicationID: $0.key, takenAt: $0.value) }
            .sorted { $0.medicationID.uuidString < $1.medicationID.uuidString }
        takenAtData = records.isEmpty ? nil : try? JSONEncoder().encode(records)
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
