import Foundation
import SwiftData
import os

/// Lightweight internal logging for persistence / notification failures that
/// were previously swallowed by `try?` (M2).
///
/// **Privacy:** never log health payloads — no mood scores, medication names,
/// doses, notes, or check-in content. Log only the operation label and the
/// error's coarse description so failures are diagnosable in Console / Xcode
/// without leaking sensitive data.
enum AppLog {
    private static let persistence = Logger(
        subsystem: "com.stewartsherpa.dosetodata", category: "persistence"
    )
    private static let notifications = Logger(
        subsystem: "com.stewartsherpa.dosetodata", category: "notifications"
    )

    /// Records a persistence (SwiftData) failure. `operation` is a short,
    /// non-sensitive label like "save medication" or "stop medication".
    static func persistenceFailure(_ operation: String, _ error: Error) {
        persistence.error("Persistence failed [\(operation, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
    }

    /// Records a notification-scheduling failure. `operation` is a short label
    /// like "schedule reminder" — never include the medication name.
    static func notificationFailure(_ operation: String, _ error: Error) {
        notifications.error("Notification failed [\(operation, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
    }
}

extension ModelContext {
    /// Saves pending changes, logging (instead of silently swallowing) any
    /// failure. Returns `true` on success. Use this in place of
    /// `try? modelContext.save()` so failures are at least observable.
    /// `operation` is a short, non-sensitive label for diagnostics.
    @discardableResult
    func saveChanges(_ operation: String) -> Bool {
        do {
            try save()
            return true
        } catch {
            AppLog.persistenceFailure(operation, error)
            return false
        }
    }
}
