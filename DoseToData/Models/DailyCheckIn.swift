import Foundation
import SwiftData

enum CheckInLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case moderate
    case high

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum StandardCheckInQuestion: String, CaseIterable, Identifiable {
    case anxiety
    case happiness
    case focus
    case irritability
    case social

    var id: String { rawValue }

    var prompt: String {
        switch self {
        case .anxiety: return "How is your current anxiety?"
        case .happiness: return "How is your happiness?"
        case .focus: return "How is your ability to focus?"
        case .irritability: return "How's your irritability?"
        case .social: return "How social were you today?"
        }
    }

    var shortLabel: String {
        switch self {
        case .anxiety: return "Anxiety"
        case .happiness: return "Happiness"
        case .focus: return "Focus"
        case .irritability: return "Irritability"
        case .social: return "Social"
        }
    }
}

struct CheckInAnswer: Codable, Hashable {
    var questionKey: String
    var level: String

    var checkInLevel: CheckInLevel? {
        CheckInLevel(rawValue: level)
    }
}

@Model
final class DailyCheckIn {
    @Attribute(.unique) var id: UUID
    var date: Date
    var answers: [CheckInAnswer]
    var note: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        answers: [CheckInAnswer] = [],
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.answers = answers
        self.note = note
    }

    func level(for question: StandardCheckInQuestion) -> CheckInLevel? {
        answers.first { $0.questionKey == question.rawValue }?.checkInLevel
    }

    func level(forCustom questionID: UUID) -> CheckInLevel? {
        answers.first { $0.questionKey == "custom:\(questionID.uuidString)" }?.checkInLevel
    }
}

@Model
final class CustomCheckInQuestion {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var createdAt: Date

    init(id: UUID = UUID(), prompt: String, createdAt: Date = Date()) {
        self.id = id
        self.prompt = prompt
        self.createdAt = createdAt
    }

    var storageKey: String { "custom:\(id.uuidString)" }
}
