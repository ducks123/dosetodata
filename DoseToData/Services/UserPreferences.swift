import Foundation
import SwiftUI

enum TrackingGoal: String, CaseIterable, Identifiable, Codable {
    case mood
    case medications
    case sideEffects
    case sleep
    case energy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mood: return "Mood"
        case .medications: return "Medications"
        case .sideEffects: return "Side effects"
        case .sleep: return "Sleep"
        case .energy: return "Energy"
        }
    }

    var icon: String {
        switch self {
        case .mood: return "heart.fill"
        case .medications: return "pill.fill"
        case .sideEffects: return "exclamationmark.triangle.fill"
        case .sleep: return "moon.fill"
        case .energy: return "bolt.fill"
        }
    }
}

@Observable
final class UserPreferences {
    private enum Keys {
        static let hasCompletedOnboarding = "dosetodata.onboarding.completed"
        static let trackingGoals = "dosetodata.onboarding.trackingGoals"
        static let disclaimerAccepted = "dosetodata.disclaimer.accepted"
        static let displayName = "dosetodata.user.displayName"
    }

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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.disclaimerAccepted = defaults.bool(forKey: Keys.disclaimerAccepted)
        self.displayName = defaults.string(forKey: Keys.displayName) ?? ""
        let rawGoals = defaults.array(forKey: Keys.trackingGoals) as? [String] ?? []
        self.trackingGoals = Set(rawGoals.compactMap(TrackingGoal.init(rawValue:)))
    }
}
