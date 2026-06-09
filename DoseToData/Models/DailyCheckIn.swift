import Foundation
import SwiftData

enum CheckInLevel: String, Codable, CaseIterable, Identifiable {
    case one = "1"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"

    var id: String { rawValue }
    var displayName: String { rawValue }
    var numericValue: Int { Int(rawValue) ?? 0 }
}

/// Structured config for a scale-type check-in question.
///
/// **Scoring convention — keep consistent across the whole app:**
/// - `min` (1) always represents the more negative / harder / higher-symptom state.
/// - `max` (5) always represents the more positive / easier / lower-symptom state.
/// - `leftAnchor` describes what value 1 means; `rightAnchor` describes what value 5 means.
/// - Daily averages, summaries, and charts use the raw stored value directly, so a
///   higher average means a better day overall — for every question, including
///   anxiety and irritability. No reverse-scoring logic should be added anywhere.
struct CheckInQuestionConfig: Identifiable, Hashable {
    let id: String
    let question: String
    let leftAnchor: String
    let rightAnchor: String
    let min: Int
    let max: Int
}

enum StandardCheckInQuestion: String, CaseIterable, Identifiable {
    // Active cases — shown in the daily check-in form and Insights charts.
    case focus
    case easeToStart
    case mood
    case energy
    case sleep
    // Retired cases — kept so existing DailyCheckIn records with these keys
    // still resolve to a label / config when rendered in historical views
    // (CheckInDetailView, past Insights data points). Not surfaced in the
    // daily check-in form anymore (see `activeCases` below).
    case anxiety
    case irritability

    var id: String { rawValue }

    /// The standard questions shown in the daily check-in form (and in
    /// Insights' default chart list). Defined as an explicit array so its
    /// order is the source of truth — independent of enum declaration order
    /// or the retired cases.
    static let activeCases: [StandardCheckInQuestion] = [
        .focus, .easeToStart, .mood, .energy, .sleep
    ]

    var isActive: Bool { Self.activeCases.contains(self) }

    /// Single source of truth for every standard question's prompt + anchor labels.
    /// Convention: 1 = harder / more symptomatic (leftAnchor), 5 = easier / better (rightAnchor).
    var config: CheckInQuestionConfig {
        switch self {
        case .focus:
            return CheckInQuestionConfig(
                id: rawValue,
                question: "How focused did you feel today?",
                leftAnchor: "Scattered",
                rightAnchor: "Focused",
                min: 1, max: 5
            )
        case .easeToStart:
            return CheckInQuestionConfig(
                id: rawValue,
                question: "How easy was it to start things?",
                leftAnchor: "Hard",
                rightAnchor: "Easy",
                min: 1, max: 5
            )
        case .mood:
            return CheckInQuestionConfig(
                id: rawValue,
                question: "How was your emotional state today?",
                leftAnchor: "Struggling",
                rightAnchor: "Steady",
                min: 1, max: 5
            )
        case .energy:
            return CheckInQuestionConfig(
                id: rawValue,
                question: "How energized did you feel?",
                leftAnchor: "Drained",
                rightAnchor: "Energized",
                min: 1, max: 5
            )
        case .sleep:
            return CheckInQuestionConfig(
                id: rawValue,
                question: "How well did you sleep last night?",
                leftAnchor: "Poor",
                rightAnchor: "Restful",
                min: 1, max: 5
            )
        // Retired — kept for historical data rendering only.
        case .anxiety:
            return CheckInQuestionConfig(
                id: rawValue,
                question: "How is your anxiety?",
                leftAnchor: "High",
                rightAnchor: "Low",
                min: 1, max: 5
            )
        case .irritability:
            return CheckInQuestionConfig(
                id: rawValue,
                question: "How is your irritability?",
                leftAnchor: "High",
                rightAnchor: "Low",
                min: 1, max: 5
            )
        }
    }

    var prompt: String { config.question }

    var shortLabel: String {
        switch self {
        case .focus:        return "Focus"
        case .easeToStart:  return "Ease to start"
        case .mood:         return "Mood"
        case .energy:       return "Energy"
        case .sleep:        return "Sleep"
        case .anxiety:      return "Anxiety"
        case .irritability: return "Irritability"
        }
    }
}

/// What kind of answer a question collects. Scale = the five-level picker;
/// text = a free-form note.
enum CheckInQuestionKind: String, Codable, CaseIterable, Identifiable {
    case scale
    case text

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scale: return "1–5 scale"
        case .text:  return "Open-ended"
        }
    }
}

struct CheckInAnswer: Codable, Hashable {
    var questionKey: String
    /// CheckInLevel rawValue for scale answers; empty string for text answers.
    var level: String
    /// Free-form response for open-ended questions. `nil` for scale answers.
    var text: String? = nil

    var checkInLevel: CheckInLevel? {
        CheckInLevel(rawValue: level)
    }

    /// Convenience builders keep existing call sites clean.
    static func scale(questionKey: String, level: CheckInLevel) -> CheckInAnswer {
        CheckInAnswer(questionKey: questionKey, level: level.rawValue, text: nil)
    }

    static func text(questionKey: String, text: String) -> CheckInAnswer {
        CheckInAnswer(questionKey: questionKey, level: "", text: text)
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

    /// Free-form response for a text-type custom question, if any.
    func text(forCustom questionID: UUID) -> String? {
        answers.first { $0.questionKey == "custom:\(questionID.uuidString)" }?.text
    }
}

@Model
final class CustomCheckInQuestion {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var createdAt: Date
    var testID: UUID? = nil
    /// Stored as a raw string so SwiftData migration is lightweight for existing rows
    /// (default `.scale` preserves prior behavior).
    var kindRaw: String = CheckInQuestionKind.scale.rawValue

    /// Anchor labels for scale-kind questions. Same convention as StandardCheckInQuestion:
    /// `leftAnchor` describes value 1 (harder), `rightAnchor` describes value 5 (better).
    /// Nil for text-kind questions, and nil for scale questions created before anchors
    /// were introduced (pre-migration rows). Optional + default-nil keeps SwiftData
    /// lightweight migration safe.
    var leftAnchor: String? = nil
    var rightAnchor: String? = nil

    var kind: CheckInQuestionKind {
        get { CheckInQuestionKind(rawValue: kindRaw) ?? .scale }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        prompt: String,
        createdAt: Date = Date(),
        testID: UUID? = nil,
        kind: CheckInQuestionKind = .scale,
        leftAnchor: String? = nil,
        rightAnchor: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.createdAt = createdAt
        self.testID = testID
        self.kindRaw = kind.rawValue
        self.leftAnchor = leftAnchor
        self.rightAnchor = rightAnchor
    }

    var storageKey: String { "custom:\(id.uuidString)" }
}

/// Heuristic for detecting when a user has set up a custom scale with the direction flipped.
///
/// Convention enforced: `leftAnchor` should describe the *harder* state (value 1),
/// `rightAnchor` should describe the *better* state (value 5), so a higher average
/// always means a better day.
///
/// Strategy: two short word lists. If an unambiguously "better"-sounding word appears
/// on the left, or an unambiguously "worse"-sounding word appears on the right, we
/// flag the pair as probably backwards. Deliberately conservative — false positives
/// (warning when it's actually correct) are worse UX than false negatives. Words like
/// "high" and "low" are excluded because they flip meaning by question ("high focus"
/// = good, "high anxiety" = bad).
enum CheckInAnchorHeuristic {
    private static let betterWords: Set<String> = [
        "good", "great", "excellent", "best", "better", "well",
        "calm", "relaxed", "peaceful", "steady",
        "easy", "focused", "clear", "sharp",
        "energetic", "rested", "alert", "awake",
        "happy", "content",
        "mild", "none", "minimal",
        "stable"
        // "strong" intentionally excluded — context-dependent ("strong urge" = bad, "strong focus" = good)
    ]

    private static let worseWords: Set<String> = [
        "bad", "terrible", "awful", "worst", "worse", "poor",
        "anxious", "stressed", "tense", "nervous",
        "hard", "difficult", "scattered",
        "tired", "foggy", "exhausted", "drained",
        "severe", "intense", "extreme",
        "painful",
        "irritable", "angry",
        "overwhelmed", "depressed", "sad"
    ]

    /// Returns true when the anchors appear to violate the 5-is-better convention.
    /// Only fires when both anchors are non-empty.
    static func looksBackwards(left: String, right: String) -> Bool {
        let leftTokens = tokenize(left)
        let rightTokens = tokenize(right)
        guard !leftTokens.isEmpty, !rightTokens.isEmpty else { return false }

        let leftLooksBetter = !leftTokens.isDisjoint(with: betterWords)
        let rightLooksWorse = !rightTokens.isDisjoint(with: worseWords)
        return leftLooksBetter || rightLooksWorse
    }

    /// Lowercases and splits on whitespace, stripping any non-letter characters.
    /// Avoids substring false-matches like "bad" matching "badge".
    private static func tokenize(_ s: String) -> Set<String> {
        Set(
            s.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }
}
