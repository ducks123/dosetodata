import Foundation

enum MedCategory: String, Codable, CaseIterable, Identifiable {
    case adhd = "ADHD"
    case depression = "Depression"
    case anxiety = "Anxiety"
    case sleep = "Sleep"
    case birthControl = "BirthControl"
    case hormonal = "Hormonal"
    case thyroid = "Thyroid"
    case glp1 = "GLP1"
    case other = "Other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .adhd: return "ADHD"
        case .depression: return "Mood"
        case .anxiety: return "Anxiety"
        case .sleep: return "Sleep"
        case .birthControl: return "Birth control"
        case .hormonal: return "Hormonal"
        case .thyroid: return "Thyroid"
        case .glp1: return "GLP-1"
        case .other: return "Other"
        }
    }
}

enum MedEventType: String, Codable, CaseIterable, Identifiable {
    case started
    case stopped
    case doseChanged
    case missedDose

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .started: return "Started a medication"
        case .stopped: return "Stopped a medication"
        case .doseChanged: return "Changed my dose"
        case .missedDose: return "Missed a dose"
        }
    }
}

enum SideEffectSeverity: String, Codable, CaseIterable, Identifiable {
    case mild
    case moderate
    case severe

    var id: String { rawValue }
}

enum ScaleType: String, Codable, CaseIterable, Identifiable {
    case asrs5 = "ASRS5"
    case phq9 = "PHQ9"
    case gad7 = "GAD7"
    case none

    var id: String { rawValue }
}
