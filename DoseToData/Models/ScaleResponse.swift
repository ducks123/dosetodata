import Foundation
import SwiftData

@Model
final class ScaleResponse {
    @Attribute(.unique) var id: UUID
    var test: Test?
    var date: Date
    var scaleType: ScaleType
    var responses: [Int]
    var totalScore: Int

    init(
        id: UUID = UUID(),
        test: Test? = nil,
        date: Date = Date(),
        scaleType: ScaleType,
        responses: [Int],
        totalScore: Int
    ) {
        self.id = id
        self.test = test
        self.date = date
        self.scaleType = scaleType
        self.responses = responses
        self.totalScore = totalScore
    }
}
