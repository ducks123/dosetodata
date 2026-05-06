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
    /// Weekday integers on which the medication is taken.
    /// Uses Calendar.weekday convention: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat.
    /// Default (empty = not yet set) is treated as every day.
    var scheduledDays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    var remindersEnabled: Bool = true

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
        scheduledTimes: [String] = [],
        scheduledDays: [Int] = [1, 2, 3, 4, 5, 6, 7],
        remindersEnabled: Bool = true
    ) {
        self.id = id
        self.medication = medication
        self.currentDose = currentDose
        self.startDate = startDate
        self.endDate = endDate
        self.schedule = schedule
        self.notes = notes
        self.scheduledTimes = scheduledTimes
        self.scheduledDays = scheduledDays
        self.remindersEnabled = remindersEnabled
    }
}
