import SwiftUI
import SwiftData

struct DailyCheckInSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]
    @Query(sort: \CustomCheckInQuestion.createdAt) private var customQuestions: [CustomCheckInQuestion]
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var allCheckIns: [DailyCheckIn]

    @State private var answers: [String: CheckInLevel] = [:]
    @State private var sideEffectsToday: [PendingSideEffect] = []
    @State private var note: String = ""
    @State private var showingAddQuestion = false
    @State private var newQuestionPrompt: String = ""
    @State private var showingAddSideEffect = false

    struct PendingSideEffect: Identifiable, Hashable {
        let id = UUID()
        var label: String
        var severity: SideEffectSeverity
    }

    private let calendar = Calendar.current

    private var existingCheckIn: DailyCheckIn? {
        allCheckIns.first { calendar.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    standardQuestionsSection
                    customQuestionsSection
                    sideEffectsSection
                    noteSection
                }
                .padding(20)
                .padding(.bottom, 100)
            }
            .background(Theme.Palette.background)
            .navigationTitle("Today's check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        finish()
                    } label: {
                        Text(existingCheckIn == nil ? "Complete" : "Update")
                            .fontWeight(.semibold)
                    }
                    .disabled(answers.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    finish()
                } label: {
                    Text(existingCheckIn == nil ? "Complete check-in" : "Update check-in")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.Palette.background.opacity(0.96))
                .disabled(answers.isEmpty)
                .opacity(answers.isEmpty ? 0.5 : 1)
            }
        }
        .sheet(isPresented: $showingAddSideEffect) {
            InlineSideEffectPicker { label, severity in
                sideEffectsToday.append(PendingSideEffect(label: label, severity: severity))
            }
            .presentationDetents([.medium])
        }
        .alert("Add a question", isPresented: $showingAddQuestion) {
            TextField("e.g. How's your sleep?", text: $newQuestionPrompt)
            Button("Cancel", role: .cancel) { newQuestionPrompt = "" }
            Button("Add") { addCustomQuestion() }
        } message: {
            Text("This question will appear in every future check-in.")
        }
        .onAppear {
            if let existing = existingCheckIn {
                for answer in existing.answers {
                    if let level = answer.checkInLevel {
                        answers[answer.questionKey] = level
                    }
                }
                note = existing.note ?? ""
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                .font(Theme.Font.heroLabel)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(existingCheckIn == nil ? "How was today?" : "Updating today's check-in")
                .font(Theme.Font.hero)
        }
    }

    private var standardQuestionsSection: some View {
        VStack(spacing: 12) {
            ForEach(StandardCheckInQuestion.allCases) { question in
                QuestionCard(
                    prompt: question.prompt,
                    selected: answers[question.rawValue]
                ) { level in
                    answers[question.rawValue] = level
                }
            }
        }
    }

    private var customQuestionsSection: some View {
        VStack(spacing: 12) {
            ForEach(customQuestions) { question in
                QuestionCard(
                    prompt: question.prompt,
                    selected: answers[question.storageKey],
                    onDelete: {
                        answers.removeValue(forKey: question.storageKey)
                        modelContext.delete(question)
                        try? modelContext.save()
                    }
                ) { level in
                    answers[question.storageKey] = level
                }
            }

            Button {
                newQuestionPrompt = ""
                showingAddQuestion = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add a question")
                    Spacer()
                }
                .font(Theme.Font.bodyEmphasis)
                .foregroundStyle(Theme.Palette.primary)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(
                            Theme.Palette.primary.opacity(0.4),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var sideEffectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Side effects today")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            if !sideEffectsToday.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(sideEffectsToday) { se in
                        HStack(spacing: 6) {
                            Text(se.label)
                                .font(Theme.Font.caption)
                            Text("· \(se.severity.rawValue)")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                            Button {
                                sideEffectsToday.removeAll { $0.id == se.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Theme.Palette.negative.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }

            Button {
                showingAddSideEffect = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add a side effect")
                    Spacer()
                }
                .font(Theme.Font.bodyEmphasis)
                .foregroundStyle(Theme.Palette.negative)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(
                            Theme.Palette.negative.opacity(0.4),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (optional)")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            TextEditor(text: $note)
                .padding(8)
                .frame(minHeight: 100)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(Theme.Palette.divider, lineWidth: 1)
                )
        }
    }

    private func addCustomQuestion() {
        let trimmed = newQuestionPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let q = CustomCheckInQuestion(prompt: trimmed)
        modelContext.insert(q)
        try? modelContext.save()
        newQuestionPrompt = ""
    }

    private func finish() {
        let encodedAnswers = answers.map { (key, level) in
            CheckInAnswer(questionKey: key, level: level.rawValue)
        }

        if let existing = existingCheckIn {
            existing.answers = encodedAnswers
            existing.note = note.isEmpty ? nil : note
            existing.date = Date()
        } else {
            let ci = DailyCheckIn(
                date: Date(),
                answers: encodedAnswers,
                note: note.isEmpty ? nil : note
            )
            modelContext.insert(ci)
        }

        for se in sideEffectsToday {
            let entry = SideEffectEntry(label: se.label, severity: se.severity)
            modelContext.insert(entry)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct QuestionCard: View {
    let prompt: String
    let selected: CheckInLevel?
    var onDelete: (() -> Void)? = nil
    let onSelect: (CheckInLevel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(prompt)
                    .font(Theme.Font.bodyEmphasis)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if let onDelete {
                    Menu {
                        Button("Remove question", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(CheckInLevel.allCases) { level in
                    Button {
                        onSelect(level)
                    } label: {
                        Text(level.displayName)
                            .font(Theme.Font.bodyEmphasis)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(backgroundColor(for: level))
                            .foregroundStyle(foregroundColor(for: level))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                    .stroke(Theme.Palette.divider, lineWidth: selected == level ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
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

    private func backgroundColor(for level: CheckInLevel) -> Color {
        selected == level ? Theme.Palette.primary : Color.white
    }

    private func foregroundColor(for level: CheckInLevel) -> Color {
        selected == level ? Color.white : Theme.Palette.textPrimary
    }
}

struct InlineSideEffectPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    @State private var label: String = ""
    @State private var severity: SideEffectSeverity = .mild

    let onAdd: (String, SideEffectSeverity) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Which one?")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(suggested, id: \.self) { s in
                            Button {
                                label = s
                            } label: {
                                Text(s)
                                    .font(Theme.Font.caption)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(label == s ? Theme.Palette.primary : Color.white)
                                    .foregroundStyle(label == s ? Color.white : Theme.Palette.textPrimary)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Theme.Palette.divider, lineWidth: label == s ? 0 : 1))
                            }
                        }
                    }

                    TextField("Or type your own", text: $label)
                        .textFieldStyle(.roundedBorder)

                    Text("How strong?")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(SideEffectSeverity.allCases) { s in
                            Button {
                                severity = s
                            } label: {
                                Text(s.rawValue.capitalized)
                                    .font(Theme.Font.bodyEmphasis)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(severity == s ? Theme.Palette.primary : Color.white)
                                    .foregroundStyle(severity == s ? Color.white : Theme.Palette.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.button)
                                            .stroke(Theme.Palette.divider, lineWidth: severity == s ? 0 : 1)
                                    )
                            }
                        }
                    }

                    Button {
                        let trimmed = label.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed, severity)
                        dismiss()
                    } label: {
                        Text("Add")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(label.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .background(Theme.Palette.background)
            .navigationTitle("Side effect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var suggested: [String] {
        let fromMeds = Array(userMedications.prefix(6)).flatMap { $0.medication.commonSideEffects }
        let fallback = [
            "Appetite suppressed", "Insomnia", "Headache", "Anxiety", "Dry mouth",
            "Nausea", "Dizziness", "Fatigue", "Irritability"
        ]
        var seen = Set<String>()
        return (fromMeds + fallback).filter { seen.insert($0).inserted }.prefix(12).map { $0 }
    }
}
