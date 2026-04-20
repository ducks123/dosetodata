import Foundation
import SwiftData

@Model
final class MedEvent {
    @Attribute(.unique) var id: UUID
    var userMedication: UserMedication?
    var type: MedEventType
    var date: Date
    var previousDose: String?
    var newDose: String?
    var notes: String?
    var test: Test?

    init(
        id: UUID = UUID(),
        userMedication: UserMedication? = nil,
        type: MedEventType,
        date: Date,
        previousDose: String? = nil,
        newDose: String? = nil,
        notes: String? = nil,
        test: Test? = nil
    ) {
        self.id = id
        self.userMedication = userMedication
        self.type = type
        self.date = date
        self.previousDose = previousDose
        self.newDose = newDose
        self.notes = notes
        self.test = test
    }
}
