import SwiftUI

struct TrackingGoalsStepView: View {
    @Environment(UserPreferences.self) private var prefs
    @Environment(AuthService.self) private var auth
    @State private var selected: Set<TrackingGoal> = []
    @State private var showSignIn = false

    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Sign in link (top right) ───────────────────────────
            HStack {
                Spacer()
                Button("Sign in") {
                    showSignIn = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Palette.primary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 10) {
                Text("Welcome · Step 1 of 4")
                    .font(Theme.Font.heroLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("What do you want\nto track?")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Your daily check-in will match what you pick. You can change it later.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(TrackingGoal.allCases) { goal in
                        GoalRow(
                            goal: goal,
                            isSelected: selected.contains(goal),
                            onTap: { toggle(goal) }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 12)
            }

            VStack(spacing: 12) {
                Button {
                    prefs.trackingGoals = selected
                    // Tailor the daily check-in to the selected goals: hide
                    // the scale questions no goal covers. Selecting no
                    // scale-mapped goal (or skipping) hides nothing.
                    prefs.hiddenStandardQuestionKeys = TrackingGoal.hiddenQuestionKeys(for: selected)
                    onContinue()
                } label: {
                    Text("Continue")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.5 : 1)

                Button("I'll figure it out") {
                    onSkip()
                }
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showSignIn) {
            AuthSheet()
                .environment(auth)
        }
    }

    private func toggle(_ goal: TrackingGoal) {
        if selected.contains(goal) {
            selected.remove(goal)
        } else {
            selected.insert(goal)
        }
    }
}

private struct GoalRow: View {
    let goal: TrackingGoal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.heroAccent)
                        .frame(width: 44, height: 44)
                    Image(systemName: goal.icon)
                        .foregroundStyle(Theme.Palette.primary)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(goal.title)
                    .font(Theme.Font.bodyEmphasis)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.Palette.primary : Theme.Palette.divider)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(isSelected ? Theme.Palette.primary : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: Theme.cardShadow.color,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
        }
        .buttonStyle(.plain)
    }
}
