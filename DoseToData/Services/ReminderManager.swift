import Foundation
import UserNotifications

@Observable
final class ReminderManager {
    static let shared = ReminderManager()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Notification category + action identifiers
    static let medReminderCategoryID = "MED_REMINDER"
    static let tookItAction          = "TOOK_IT"
    static let skipTodayAction       = "SKIP_TODAY"

    private init() {}

    /// Register the medication reminder category with "Took it" and "Skip today"
    /// quick-actions. Call once at app launch.
    func setupNotificationCategories() {
        let tookIt = UNNotificationAction(
            identifier: Self.tookItAction,
            title: "✓ Took it",
            options: []
        )
        let skip = UNNotificationAction(
            identifier: Self.skipTodayAction,
            title: "Skip today",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.medReminderCategoryID,
            actions: [tookIt, skip],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
        }
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            await refreshAuthorizationStatus()
            return granted
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func scheduleReminders(for userMed: UserMedication) async {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }

        await clearReminders(for: userMed.id)

        let medName = userMed.medication.brandName
        let dose = userMed.currentDose
        // Treat empty scheduledDays as every day (handles older records before the field existed).
        let days = userMed.scheduledDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : userMed.scheduledDays

        for timeString in userMed.scheduledTimes {
            guard let (hour, minute) = parse(timeString) else { continue }
            for weekday in days {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                components.weekday = weekday   // fires only on this calendar weekday

                let content = UNMutableNotificationContent()
                content.title = "Time for \(medName)"
                content.body = dose.isEmpty ? "Tap to log this dose." : "\(dose) — tap to log this dose."
                content.sound = .default
                content.threadIdentifier = userMed.id.uuidString
                content.categoryIdentifier = Self.medReminderCategoryID

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let id = identifier(userMedID: userMed.id, timeString: timeString, weekday: weekday)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                await addNotification(request, operation: "schedule reminder")
            }
        }
    }

    /// Adds a notification request, logging (not swallowing) failures so a
    /// silently-missed reminder is at least diagnosable (M2). `operation` is a
    /// short non-sensitive label — never the medication name.
    private func addNotification(_ request: UNNotificationRequest, operation: String) async {
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLog.notificationFailure(operation, error)
        }
    }

    func clearReminders(for userMedID: UUID) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let prefix = Self.reminderIdentifierPrefix(userMedID: userMedID)
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Check-in reminders (multi-time)

    private static let checkInReminderPrefix = "checkInReminder-"

    /// Schedule repeating notifications for every time in `times` (array of "HH:mm" strings).
    /// Cancels any previously scheduled check-in reminders first.
    func scheduleCheckInReminders(times: [String]) async {
        let granted = await requestAuthorizationIfNeeded()
        await cancelAllCheckInReminders()   // awaited so cancel finishes before scheduling
        guard granted, !times.isEmpty else { return }

        for timeString in times {
            let parts = timeString.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else { continue }

            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let content = UNMutableNotificationContent()
            content.title = "How did today go?"
            content.body = "Tap to log your daily check-in."
            content.sound = .default
            content.threadIdentifier = "checkInReminder"

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let id = Self.checkInReminderPrefix + timeString
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            await addNotification(request, operation: "schedule reminder")
        }
    }

    func cancelAllCheckInReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.checkInReminderPrefix) }
        if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
    }

    // MARK: - Legacy single daily check-in reminder (used by SettingsView)

    private static let dailyCheckInIdentifier = "dailyCheckInReminder"

    func scheduleDailyCheckInReminder(hour: Int, minute: Int) async {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyCheckInIdentifier])
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let content = UNMutableNotificationContent()
        content.title = "How did today go?"
        content.body = "Tap to check in."
        content.sound = .default
        content.threadIdentifier = Self.dailyCheckInIdentifier
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.dailyCheckInIdentifier, content: content, trigger: trigger)
        await addNotification(request, operation: "schedule reminder")
    }

    func cancelDailyCheckInReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.dailyCheckInIdentifier])
    }

    // MARK: - Streak milestone notifications

    /// Fires an immediate local notification celebrating a streak milestone (7/30/60/100 days).
    /// Safe to call after every check-in — no-ops unless the streak is exactly a milestone day.
    func fireMilestoneNotificationIfNeeded(streak: Int) async {
        guard AppState.milestoneDays.contains(streak) else { return }
        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }

        let center = UNUserNotificationCenter.current()
        let id = "streakMilestone-\(streak)"

        // Don't fire the same milestone twice
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        let alreadySent = pending.contains { $0.identifier == id }
            || delivered.contains { $0.request.identifier == id }
        guard !alreadySent else { return }

        let (title, body): (String, String) = switch streak {
        case 7:   ("7-day streak! 🔥", "A full week of check-ins. You're building a real habit.")
        case 30:  ("30-day streak! 🏆", "One month strong. Your data is telling a story.")
        case 60:  ("60-day streak! 💪", "Two months of insights. That's impressive dedication.")
        case 100: ("100 days! 🌟", "Triple digits. You've built something most people never do.")
        default:  ("Streak milestone!", "Keep it going!")
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Fire after a short delay so it arrives after the app moves to background
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        await addNotification(request, operation: "schedule reminder")
    }

    private func identifier(userMedID: UUID, timeString: String, weekday: Int) -> String {
        Self.reminderIdentifier(userMedID: userMedID, timeString: timeString, weekday: weekday)
    }

    /// Shared prefix for ALL of a medication's reminder request identifiers.
    /// `clearReminders(for:)` removes exactly the requests with this prefix, so
    /// scheduling and clearing must agree on it — these statics are the single
    /// source of truth (and are unit-tested).
    static func reminderIdentifierPrefix(userMedID: UUID) -> String {
        "userMed-\(userMedID.uuidString)"
    }

    static func reminderIdentifier(userMedID: UUID, timeString: String, weekday: Int) -> String {
        "\(reminderIdentifierPrefix(userMedID: userMedID))-\(timeString)-\(weekday)"
    }

    private func parse(_ timeString: String) -> (hour: Int, minute: Int)? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1])
        else { return nil }
        return (hour, minute)
    }
}
