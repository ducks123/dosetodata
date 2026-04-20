import Foundation
import SwiftData

@Model
final class SideEffectEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var label: String
    var severity: SideEffectSeverity
    var note: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        label: String,
        severity: SideEffectSeverity,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.label = label
        self.severity = severity
        self.note = note
    }
}
