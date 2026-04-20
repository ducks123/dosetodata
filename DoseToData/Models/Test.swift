import Foundation
import SwiftData

@Model
final class Test {
    @Attribute(.unique) var id: UUID
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
        startEvent: MedEvent? = nil,
        startDate: Date,
        plannedEndDate: Date? = nil,
        actualEndDate: Date? = nil,
        watchingFor: String,
        weeklyScalesEnabled: Bool = false,
        scaleType: ScaleType? = nil
    ) {
        self.id = id
        self.startEvent = startEvent
        self.startDate = startDate
        self.plannedEndDate = plannedEndDate
        self.actualEndDate = actualEndDate
        self.watchingFor = watchingFor
        self.weeklyScalesEnabled = weeklyScalesEnabled
        self.scaleType = scaleType
    }
}
