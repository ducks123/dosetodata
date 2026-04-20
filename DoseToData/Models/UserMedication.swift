import Foundation
import SwiftData

@Model
final class UserMedication {
    @Attribute(.unique) var id: UUID
    var medication: Medication
    var currentDose: String
    var startDate: Date
    var endDate: Date?
    var schedule: String?
    var notes: String?
    var scheduledTimes: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \MedEvent.userMedication)
    var events: [MedEvent] = []

    init(
        id: UUID = UUID(),
        medication: Medication,
        currentDose: String,
        startDate: Date,
        endDate: Date? = nil,
        schedule: String? = nil,
        notes: String? = nil,
        scheduledTimes: [String] = []
    ) {
        self.id = id
        self.medication = medication
        self.currentDose = currentDose
        self.startDate = startDate
        self.endDate = endDate
        self.schedule = schedule
        self.notes = notes
        self.scheduledTimes = scheduledTimes
    }
}
