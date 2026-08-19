import Foundation
import SwiftUI

enum TrackingGoal: String, CaseIterable, Identifiable, Codable {
    case mood
    case focus
    case medications
    case sideEffects
    case sleep
    case energy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mood: return "Mood"
        case .focus: return "Focus"
        case .medications: return "Medications"
        case .sideEffects: return "Side effects"
        case .sleep: return "Sleep"
        case .energy: return "Energy"
        }
    }

    var icon: String {
        switch self {
        case .mood: return "heart.fill"
        case .focus: return "scope"
        case .medications: return "pill.fill"
        case .sideEffects: return "exclamationmark.triangle.fill"
        case .sleep: return "moon.fill"
        case .energy: return "bolt.fill"
        }
    }

    /// Standard check-in questions this goal maps to. Goals with no scale
    /// question (medications, side effects) return [] — those are covered by
    /// the adherence and side-effect cards, which always show.
    var mappedQuestions: [StandardCheckInQuestion] {
        switch self {
        case .mood:   return [.mood]
        case .focus:  return [.focus, .easeToStart]
        case .energy: return [.energy]
        case .sleep:  return [.sleep]
        case .medications, .sideEffects: return []
        }
    }

    /// Hidden-question keys implied by a goal selection: every mappable
    /// standard question NOT covered by the selected goals. Empty (nothing
    /// hidden) when no scale-mapped goal was selected — hiding everything
    /// would gut the check-in, so we fall back to showing all questions.
    static func hiddenQuestionKeys(for selection: Set<TrackingGoal>) -> Set<String> {
        let covered = Set(selection.flatMap(\.mappedQuestions))
        guard !covered.isEmpty else { return [] }
        let mappable = Set(allCases.flatMap(\.mappedQuestions))
        return Set(mappable.subtracting(covered).map(\.rawValue))
    }
}

@Observable
final class UserPreferences {
    private enum Keys {
        static let hasCompletedOnboarding = "dosetodata.onboarding.completed"
        static let trackingGoals = "dosetodata.onboarding.trackingGoals"
        static let disclaimerAccepted = "dosetodata.disclaimer.accepted"
        static let displayName = "dosetodata.user.displayName"
        static let dailyCheckInReminderEnabled = "dosetodata.reminders.dailyCheckIn.enabled"
        static let dailyCheckInReminderTime = "dosetodata.reminders.dailyCheckIn.time"
        static let checkInReminderTimes = "dosetodata.reminders.checkIn.times"
        static let hiddenStandardQuestionKeys = "dosetodata.checkIn.hiddenStandardKeys"
    }

    /// Default time for the end-of-day check-in reminder.
    static let defaultDailyCheckInTime = "20:00"
    /// Default reminder times: 5 PM only.
    static let defaultCheckInReminderTimes: [String] = ["17:00"]

    private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var disclaimerAccepted: Bool {
        didSet { defaults.set(disclaimerAccepted, forKey: Keys.disclaimerAccepted) }
    }

    var trackingGoals: Set<TrackingGoal> {
        didSet {
            let raw = trackingGoals.map { $0.rawValue }
            defaults.set(raw, forKey: Keys.trackingGoals)
        }
    }

    var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }

    /// Whether the user wants a daily push to do their check-in.
    var dailyCheckInReminderEnabled: Bool {
        didSet { defaults.set(dailyCheckInReminderEnabled, forKey: Keys.dailyCheckInReminderEnabled) }
    }

    /// Stored as "HH:mm" (24-hour). Use `dailyCheckInReminderComponents` to read.
    var dailyCheckInReminderTime: String {
        didSet { defaults.set(dailyCheckInReminderTime, forKey: Keys.dailyCheckInReminderTime) }
    }

    /// Parsed hour/minute from `dailyCheckInReminderTime`, falling back to 8pm if malformed.
    var dailyCheckInReminderComponents: (hour: Int, minute: Int) {
        let parts = dailyCheckInReminderTime.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              (0...23).contains(h),
              (0...59).contains(m)
        else { return (20, 0) }
        return (h, m)
    }

    /// Array of "HH:mm" times the user wants check-in reminders.
    /// Empty = no reminders. Default is 5 PM.
    var checkInReminderTimes: [String] {
        didSet { defaults.set(checkInReminderTimes, forKey: Keys.checkInReminderTimes) }
    }

    /// rawValues of standard check-in questions the user has hidden from the
    /// daily check-in form. Hidden questions don't appear in the check-in
    /// sheet or Insights charts, but historical data with these keys is
    /// preserved and still rendered in past check-in detail views. The user
    /// can restore a hidden question from the "Add question" sheet.
    var hiddenStandardQuestionKeys: Set<String> {
        didSet {
            defaults.set(Array(hiddenStandardQuestionKeys), forKey: Keys.hiddenStandardQuestionKeys)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.disclaimerAccepted = defaults.bool(forKey: Keys.disclaimerAccepted)
        self.displayName = defaults.string(forKey: Keys.displayName) ?? ""
        let rawGoals = defaults.array(forKey: Keys.trackingGoals) as? [String] ?? []
        self.trackingGoals = Set(rawGoals.compactMap(TrackingGoal.init(rawValue:)))
        // Legacy single-reminder fields (kept for Settings time-picker compat)
        if defaults.object(forKey: Keys.dailyCheckInReminderEnabled) == nil {
            self.dailyCheckInReminderEnabled = true
            defaults.set(true, forKey: Keys.dailyCheckInReminderEnabled)
        } else {
            self.dailyCheckInReminderEnabled = defaults.bool(forKey: Keys.dailyCheckInReminderEnabled)
        }
        self.dailyCheckInReminderTime = defaults.string(forKey: Keys.dailyCheckInReminderTime)
            ?? Self.defaultDailyCheckInTime
        // Multi-reminder times — default 5 PM for new installs
        self.checkInReminderTimes = (defaults.array(forKey: Keys.checkInReminderTimes) as? [String])
            ?? Self.defaultCheckInReminderTimes
        let rawHidden = defaults.array(forKey: Keys.hiddenStandardQuestionKeys) as? [String] ?? []
        self.hiddenStandardQuestionKeys = Set(rawHidden)
    }
}
