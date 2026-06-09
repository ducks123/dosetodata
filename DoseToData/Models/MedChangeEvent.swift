import Foundation
import SwiftData

/// A single "psychiatrist appointment" worth of medication changes — one or
/// more `MedAction`s logged together with a shared date, optionally with a
/// free-text note about what the user is watching for in their data going
/// forward.
///
/// This is the replacement for the legacy `Test` model going forward. Existing
/// `Test` records remain in the database and still render as chart markers on
/// Insights for backward compatibility, but new entries are created as
/// `MedChangeEvent`s.
@Model
final class MedChangeEvent {
    @Attribute(.unique) var id: UUID
    /// The day this change happened — drives chart marker placement on
    /// Insights and the date shown in "Recent changes" on Today.
    var date: Date
    /// Free-text note about what symptoms / outcomes the user is watching
    /// for after this change. Rendered in the marker detail sheet.
    var watchingFor: String?
    /// When the record was created (separate from `date` since the user can
    /// backdate a change).
    var createdAt: Date

    /// One row per medication action bundled into this event (e.g. started
    /// Adderall + decreased Wellbutrin both happened at the same appointment).
    @Relationship(deleteRule: .cascade, inverse: \MedAction.event)
    var actions: [MedAction] = []

    init(
        id: UUID = UUID(),
        date: Date,
        watchingFor: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.watchingFor = watchingFor
        self.createdAt = createdAt
    }

    /// One-line summary used in the "Recent changes" list on Today and the
    /// chart marker detail. e.g. "2 changes" or "Wellbutrin ↓ 300 → 150mg".
    var summaryLine: String {
        if actions.count == 1, let a = actions.first {
            return a.summaryLine
        }
        return "\(actions.count) changes"
    }
}

/// A single med-level action inside a `MedChangeEvent`. The three kinds
/// (start / stop / doseChange) match what psychiatrists actually say at
/// appointments: started, stopped, or changed the dose of a medication.
@Model
final class MedAction {
    @Attribute(.unique) var id: UUID
    /// Back-link to the parent event. Optional because SwiftData's inverse
    /// relationship requires it, but in practice always set.
    var event: MedChangeEvent?
    /// The medication this action applies to.
    var medication: Medication
    /// One of `MedAction.Kind` cases, persisted as raw string.
    var kindRaw: String
    /// Dose AFTER this action.
    /// - `.start` → the starting dose ("10mg")
    /// - `.doseChange` → the new dose ("150mg")
    /// - `.stop` → nil
    var dose: String?
    /// Dose BEFORE this action — only used for `.doseChange` so the marker
    /// detail can render "300 → 150mg".
    var previousDose: String?

    enum Kind: String, CaseIterable, Identifiable {
        case start
        case stop
        case doseChange

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .start:      return "Started"
            case .stop:       return "Stopped"
            case .doseChange: return "Dose change"
            }
        }

        /// Arrow / glyph used in summary lines. "+" for start, "−" for stop,
        /// "↕" for dose change.
        var glyph: String {
            switch self {
            case .start:      return "+"
            case .stop:       return "−"
            case .doseChange: return "↕"
            }
        }
    }

    var kind: Kind {
        get { Kind(rawValue: kindRaw) ?? .doseChange }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        medication: Medication,
        kind: Kind,
        dose: String? = nil,
        previousDose: String? = nil
    ) {
        self.id = id
        self.medication = medication
        self.kindRaw = kind.rawValue
        self.dose = dose
        self.previousDose = previousDose
    }

    /// Human-readable single-line description of this action.
    /// e.g. "Adderall + Started 10mg", "Wellbutrin ↕ 300 → 150mg", "Lexapro − Stopped".
    var summaryLine: String {
        let name = medication.brandName
        switch kind {
        case .start:
            let dosePart = dose.map { " \($0)" } ?? ""
            return "\(name) + Started\(dosePart)"
        case .stop:
            return "\(name) − Stopped"
        case .doseChange:
            switch (previousDose, dose) {
            case let (.some(prev), .some(new)):
                return "\(name) ↕ \(prev) → \(new)"
            case (_, .some(let new)):
                return "\(name) ↕ \(new)"
            default:
                return "\(name) ↕ Dose change"
            }
        }
    }
}
