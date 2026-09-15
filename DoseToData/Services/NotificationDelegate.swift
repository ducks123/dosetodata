import Foundation
import UserNotifications
import SwiftData

/// Handles notification presentation and quick-action responses (Taken / Skip today).
/// Set as `UNUserNotificationCenter.current().delegate` at app launch.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Injected by the App at launch so the delegate can write to SwiftData
    /// from a background notification callback.
    var modelContainer: ModelContainer?

    private override init() { super.init() }

    // Show banners + play sound even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Called when the user taps "Taken" or "Skip today" from the lock screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            await handleAction(response: response)
            completionHandler()
        }
    }

    // MARK: - Action handling

    @MainActor
    private func handleAction(response: UNNotificationResponse) async {
        let actionID = response.actionIdentifier
        guard actionID == ReminderManager.tookItAction ||
              actionID == ReminderManager.skipTodayAction else { return }

        let request = response.notification.request
        let groupedIDs = (request.content.userInfo[ReminderManager.medicationIDsUserInfoKey] as? [String])?
            .compactMap(UUID.init(uuidString:)) ?? []
        let medicationIDs = groupedIDs.isEmpty
            ? Self.legacyMedicationIDs(from: request.identifier)
            : groupedIDs
        guard !medicationIDs.isEmpty, let container = modelContainer else { return }

        let context = ModelContext(container)

        // Idempotent: returns today's canonical log, merging any duplicates
        // created by a racing check-in save on the main context (M3).
        let log = AdherenceLogStore.upsert(for: Date(), in: context)

        switch actionID {
        case ReminderManager.tookItAction:
            for medicationID in medicationIDs where !log.takenMedIDs.contains(medicationID) {
                log.takenMedIDs.append(medicationID)
            }
            log.skippedMedIDs.removeAll { medicationIDs.contains($0) }
            log.recordTaken(medicationIDs, at: Date())
        case ReminderManager.skipTodayAction:
            for medicationID in medicationIDs where !log.skippedMedIDs.contains(medicationID) {
                log.skippedMedIDs.append(medicationID)
            }
            for medicationID in medicationIDs {
                log.clearTakenTimestamp(for: medicationID)
            }
            log.takenMedIDs.removeAll { medicationIDs.contains($0) }
        default:
            break
        }

        context.saveChanges("adherence quick action")
    }

    /// Notifications delivered by an older build may still use the original
    /// per-medication identifier. Keep those quick actions functional during
    /// the transition without ever displaying the medication name.
    private static func legacyMedicationIDs(from identifier: String) -> [UUID] {
        guard identifier.hasPrefix("userMed-") else { return [] }
        let suffix = String(identifier.dropFirst("userMed-".count))
        guard suffix.count >= 36,
              let medicationID = UUID(uuidString: String(suffix.prefix(36)))
        else { return [] }
        return [medicationID]
    }
}
