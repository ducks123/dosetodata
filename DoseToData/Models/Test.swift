import Foundation
import SwiftData

@Model
final class Test {
    @Attribute(.unique) var id: UUID
    var name: String = ""
    var startEvent: MedEvent?
    var startDate: Date
    var plannedEndDate: Date?
    var actualEndDate: Date?
    var watchingFor: String
    var weeklyScalesEnabled: Bool
    var scaleType: ScaleType?

    @Relationship(deleteRule: .cascade, inverse: \ScaleResponse.test)
    var scaleResponses: [ScaleResponse] = []

    init(
        id: UUID = UUID(),
        name: String = "",
        startEvent: MedEvent? = nil,
        startDate: Date,
        plannedEndDate: Date? = nil,
        actualEndDate: Date? = nil,
        watchingFor: String,
        weeklyScalesEnabled: Bool = false,
        scaleType: ScaleType? = nil
    ) {
        self.id = id
        self.name = name
        self.startEvent = startEvent
        self.startDate = startDate
        self.plannedEndDate = plannedEndDate
        self.actualEndDate = actualEndDate
        self.watchingFor = watchingFor
        self.weeklyScalesEnabled = weeklyScalesEnabled
        self.scaleType = scaleType
    }

    var displayName: String {
        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        let medName = startEvent?.userMedication?.medication.brandName ?? "Test"
        return medName
    }
}
