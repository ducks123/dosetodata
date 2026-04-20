import SwiftUI
import SwiftData

struct DailyCheckInSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    let existingMood: MoodEntry?

    @State private var step: Int = 0
    @State private var moodScore: Double = 7
    @State private var hadSideEffect: Bool? = nil
    @State private var sideEffectLabel: String = ""
    @State private var sideEffectSeverity: SideEffectSeverity = .mild
    @State private var note: String = ""

    private let steps = ["Mood", "Side effects", "Note"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                ScrollView {
                    Group {
                        switch step {
                        case 0: moodStep
                        case 1: sideEffectStep
                        default: noteStep
                        }
                    }
                    .padding(24)
                }
                footer
            }
            .background(Theme.Palette.background)
            .navigationTitle("Today's check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if let existingMood {
                    moodScore = Double(existingMood.moodScore)
                    note = existingMood.note ?? ""
                }
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { idx in
                Capsule()
                    .fill(idx <= step ? Theme.Palette.primary : Theme.Palette.divider)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var moodStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("How are you today?")
                .font(Theme.Font.hero)
            Text("1 is rough, 10 is great. Go with your gut.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)

            HStack(spacing: 8) {
                Text("\(Int(moodScore))")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Theme.Palette.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: moodScore)
                Text("/ 10")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Slider(value: $moodScore, in: 1...10, step: 1)
                .tint(Theme.Palette.primary)

            HStack {
                Text("Rough")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Text("Great")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }

    private var sideEffectStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Any side effects today?")
                .font(Theme.Font.hero)
            Text("Logging even \"nothing unusual\" is useful. Quick answer, then move on.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)

            HStack(spacing: 10) {
                ChoiceChip(label: "Nothing unusual", isSelected: hadSideEffect == false) {
                    hadSideEffect = false
                    sideEffectLabel = ""
                }
                ChoiceChip(label: "Yeah, something", isSelected: hadSideEffect == true) {
                    hadSideEffect = true
                }
            }

            if hadSideEffect == true {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Which one?")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(suggestedLabels, id: \.self) { label in
                            Button {
                                sideEffectLabel = label
                            } label: {
                                Text(label)
                                    .font(Theme.Font.caption)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(sideEffectLabel == label ? Theme.Palette.primary : Color.white)
                                    .foregroundStyle(sideEffectLabel == label ? Color.white : Theme.Palette.textPrimary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(Theme.Palette.divider, lineWidth: sideEffectLabel == label ? 0 : 1)
                                    )
                            }
                        }
                    }
                    TextField("Or type your own", text: $sideEffectLabel)
                        .textFieldStyle(.roundedBorder)

                    Text("How strong?")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(SideEffectSeverity.allCases) { option in
                            Button {
                                sideEffectSeverity = option
                            } label: {
                                Text(option.rawValue.capitalized)
                                    .font(Theme.Font.bodyEmphasis)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(sideEffectSeverity == option ? Theme.Palette.primary : Color.white)
                                    .foregroundStyle(sideEffectSeverity == option ? Color.white : Theme.Palette.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.button)
                                            .stroke(Theme.Palette.divider, lineWidth: sideEffectSeverity == option ? 0 : 1)
                                    )
                            }
                        }
                    }
                }
            }
        }
    }

    private var noteStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Anything worth remembering?")
                .font(Theme.Font.hero)
            Text("Optional — a sentence or two about what affected your day. You can skip this.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)

            TextEditor(text: $note)
                .padding(8)
                .frame(minHeight: 160)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .stroke(Theme.Palette.divider, lineWidth: 1)
                )
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    step -= 1
                } label: {
                    Text("Back")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button {
                if step < steps.count - 1 {
                    step += 1
                } else {
                    finish()
                }
            } label: {
                Text(step < steps.count - 1 ? "Next" : "Complete check-in")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(nextDisabled)
            .opacity(nextDisabled ? 0.5 : 1)
        }
        .padding(20)
        .background(Theme.Palette.background)
    }

    private var nextDisabled: Bool {
        if step == 1 && hadSideEffect == nil { return true }
        if step == 1 && hadSideEffect == true && sideEffectLabel.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return false
    }

    private var suggestedLabels: [String] {
        let fromMeds = Array(userMedications.prefix(6)).flatMap { $0.medication.commonSideEffects }
        let fallback = [
            "Appetite suppressed", "Insomnia", "Headache", "Anxiety", "Dry mouth",
            "Nausea", "Dizziness", "Fatigue", "Irritability"
        ]
        var seen = Set<String>()
        return (fromMeds + fallback).filter { seen.insert($0).inserted }.prefix(12).map { $0 }
    }

    private func finish() {
        let score = Int(moodScore)
        if let existingMood {
            existingMood.moodScore = score
            existingMood.note = note.isEmpty ? nil : note
            existingMood.date = Date()
        } else {
            let entry = MoodEntry(moodScore: score, note: note.isEmpty ? nil : note)
            modelContext.insert(entry)
        }

        if hadSideEffect == true {
            let label = sideEffectLabel.trimmingCharacters(in: .whitespaces)
            if !label.isEmpty {
                let se = SideEffectEntry(label: label, severity: sideEffectSeverity)
                modelContext.insert(se)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct ChoiceChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Font.bodyEmphasis)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Theme.Palette.primary : Color.white)
                .foregroundStyle(isSelected ? Color.white : Theme.Palette.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .stroke(Theme.Palette.divider, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
