import SwiftUI
import SwiftData

/// Onboarding step that frames and presents the user's real first check-in.
/// Reuses `DailyCheckInSheet` so the experience is exactly the daily product —
/// no separate onboarding form to maintain. Skippable: nobody gets trapped in
/// a form mid-onboarding.
struct OnboardingCheckInStepView: View {
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var allCheckIns: [DailyCheckIn]

    @State private var showingCheckIn = false

    /// Called when the user saved a check-in for today.
    let onSaved: () -> Void
    /// Called when the user skips without checking in.
    let onSkip: () -> Void

    private var hasCheckInToday: Bool {
        let calendar = Calendar.current
        return allCheckIns.contains { calendar.isDateInToday($0.date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Last step · Step 4 of 4")
                    .font(Theme.Font.heroLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("Log your\nfirst day.")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("This is the same quick check-in you'll do each day. One answer is enough to put your first point on the chart.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CheckInPromisePoint(
                        icon: "timer",
                        text: "Takes about 30 seconds"
                    )
                    CheckInPromisePoint(
                        icon: "hand.point.up.left.fill",
                        text: "Answer only what matters to you"
                    )
                    CheckInPromisePoint(
                        icon: "chart.xyaxis.line",
                        text: "Every day adds a point to your trends"
                    )
                }
                .padding(24)
            }

            VStack(spacing: 10) {
                Button {
                    showingCheckIn = true
                } label: {
                    Text("Start my first check-in")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Skip for now") {
                    onSkip()
                }
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showingCheckIn, onDismiss: {
            // The sheet saves on its own; advance only if a check-in for
            // today actually exists (i.e. the user saved, not cancelled).
            if hasCheckInToday { onSaved() }
        }) {
            DailyCheckInSheet()
        }
    }
}

private struct CheckInPromisePoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.heroAccent)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundStyle(Theme.Palette.primary)
                    .font(.system(size: 16, weight: .semibold))
            }
            Text(text)
                .font(Theme.Font.bodyEmphasis)
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(
            color: Theme.cardShadow.color,
            radius: Theme.cardShadow.radius,
            x: Theme.cardShadow.x,
            y: Theme.cardShadow.y
        )
    }
}
