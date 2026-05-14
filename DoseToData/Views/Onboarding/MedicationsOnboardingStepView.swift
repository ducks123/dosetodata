import SwiftUI
import SwiftData

struct MedicationsOnboardingStepView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    @State private var showingAddFlow = false

    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Step 2 of 4")
                    .font(Theme.Font.heroLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("Any medications\nyou're taking now?")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Add what you're on. Set a dose, time of day, and reminders if you want them.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            ScrollView {
                VStack(spacing: 12) {
                    if !userMedications.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Added")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                            ForEach(userMedications) { userMed in
                                AddedMedRow(userMed: userMed) {
                                    modelContext.delete(userMed)
                                    try? modelContext.save()
                                }
                            }
                        }
                        .padding(.top, 24)
                    }

                    Button {
                        showingAddFlow = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text(userMedications.isEmpty ? "Add a medication" : "Add another medication")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, userMedications.isEmpty ? 32 : 16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            VStack(spacing: 12) {
                Button {
                    onContinue()
                } label: {
                    Text(userMedications.isEmpty ? "Continue without adding" : "Continue")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("I'll add later") {
                    onSkip()
                }
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showingAddFlow) {
            // Reuse the exact same flow as Schedule → Edit medications.
            // It handles library search, custom medication form, dose
            // picker, time-of-day scheduling, and wires up reminders via
            // ReminderManager on save.
            AddMedicationFlow { userMed in
                modelContext.insert(userMed)
                try? modelContext.save()
            }
        }
    }
}

private struct AddedMedRow: View {
    let userMed: UserMedication
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(userMed.medication.category.pastelColor)
                    .frame(width: 40, height: 40)
                Image(systemName: userMed.medication.category.iconSystemName)
                    .foregroundStyle(Theme.Palette.primary)
                    .font(.system(size: 16, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(userMed.medication.brandName)
                    .font(Theme.Font.bodyEmphasis)
                Text(detailLine)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(12)
        .background(Theme.Palette.heroAccent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var detailLine: String {
        var parts: [String] = [userMed.currentDose]
        if !userMed.scheduledTimes.isEmpty {
            // Show first time, plus a "+N" if there's more.
            let firstTime = userMed.scheduledTimes.first ?? ""
            let extra = userMed.scheduledTimes.count - 1
            parts.append(extra > 0 ? "\(firstTime) +\(extra)" : firstTime)
        }
        parts.append("started \(userMed.startDate.formatted(date: .abbreviated, time: .omitted))")
        return parts.joined(separator: " · ")
    }
}
