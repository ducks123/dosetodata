import SwiftUI

/// Final onboarding step, shown after the paywall: offer a daily check-in
/// reminder and — if accepted — request notification permission and actually
/// register it with iOS.
///
/// This step exists because a "default" reminder time in UserPreferences is
/// worthless unless something calls `scheduleCheckInReminders`; before this
/// step, that only ever happened if the user found the bell icon on Today.
struct ReminderPrimerStepView: View {
    @Environment(UserPreferences.self) private var prefs

    @State private var selectedTime: Date = ReminderPrimerStepView.defaultTime()
    @State private var isScheduling = false

    let onDone: () -> Void

    private static func defaultTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 17
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private var selectedTimeString: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        return String(format: "%02d:%02d", components.hour ?? 17, components.minute ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("One last thing")
                    .font(Theme.Font.heroLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("A daily nudge\nbuilds the habit.")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("One gentle reminder a day keeps your chart filling in. You can change the time or turn it off anytime from the Today tab.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            VStack(spacing: 4) {
                Text("Remind me at")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(
                color: Theme.cardShadow.color,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    guard !isScheduling else { return }
                    isScheduling = true
                    let times = [selectedTimeString]
                    prefs.checkInReminderTimes = times
                    Task {
                        // Requests notification permission internally if the
                        // user hasn't been asked yet.
                        await ReminderManager.shared.scheduleCheckInReminders(times: times)
                        onDone()
                    }
                } label: {
                    Text(isScheduling ? "Setting up…" : "Remind me daily")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isScheduling)

                Button("Not now") {
                    // Clear the phantom default so the reminder sheet never
                    // shows a time as "on" that was never registered with iOS.
                    prefs.checkInReminderTimes = []
                    onDone()
                }
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .disabled(isScheduling)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }
}
