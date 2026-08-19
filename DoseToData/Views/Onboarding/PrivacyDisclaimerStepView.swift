import SwiftUI

struct PrivacyDisclaimerStepView: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Before you start · Step 2 of 4")
                    .font(Theme.Font.heroLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("A few things\nto know.")
                    .font(Theme.Font.hero)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    DisclaimerPoint(
                        icon: "lock.fill",
                        title: "Private by design",
                        detail: "Everything you track stays on your phone. Nothing is uploaded, and no account is required."
                    )
                    DisclaimerPoint(
                        icon: "stethoscope",
                        title: "Not a medical device",
                        detail: "DoseToData helps you notice patterns. It does not diagnose, treat, or replace medical advice."
                    )
                    DisclaimerPoint(
                        icon: "person.2.fill",
                        title: "For use with your clinician",
                        detail: "Use what you track here in conversation with your prescribing doctor — not instead of them."
                    )
                }
                .padding(24)
            }

            Button {
                onAccept()
            } label: {
                Text("I understand")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

private struct DisclaimerPoint: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.heroAccent)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundStyle(Theme.Palette.primary)
                    .font(.system(size: 16, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Font.bodyEmphasis)
                Text(detail)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
