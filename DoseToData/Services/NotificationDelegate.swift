import Foundation
import UserNotifications
import SwiftData

/// Handles notification presentation and quick-action responses (Took it / Skip today).
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

    // Called when the user taps "Took it" or "Skip today" from the lock screen.
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

        // Notification identifier format: "userMed-{36-char-UUID}-{timeString}-{weekday}"
        let identifier = response.notification.request.identifier
        guard identifier.hasPrefix("userMed-") else { return }
        let afterPrefix = String(identifier.dropFirst("userMed-".count))
        guard afterPrefix.count >= 36,
              let medID = UUID(uuidString: String(afterPrefix.prefix(36))),
              let container = modelContainer
        else { return }

        let context = ModelContext(container)

        // Idempotent: returns today's canonical log, merging any duplicates
        // created by a racing check-in save on the main context (M3).
        let log = AdherenceLogStore.upsert(for: Date(), in: context)

        switch actionID {
        case ReminderManager.tookItAction:
            if !log.takenMedIDs.contains(medID) { log.takenMedIDs.append(medID) }
            log.skippedMedIDs.removeAll { $0 == medID }
        case ReminderManager.skipTodayAction:
            if !log.skippedMedIDs.contains(medID) { log.skippedMedIDs.append(medID) }
            log.takenMedIDs.removeAll { $0 == medID }
        default:
            break
        }

        context.saveChanges("adherence quick action")
    }
}
