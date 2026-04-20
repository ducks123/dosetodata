import Foundation
import SwiftData

@Model
final class MoodEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var moodScore: Int
    var note: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        moodScore: Int,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.moodScore = moodScore
        self.note = note
    }
}
