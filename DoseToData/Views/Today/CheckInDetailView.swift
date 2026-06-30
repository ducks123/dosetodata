import SwiftUI
import SwiftData

/// Read-only view that displays all answers from a single DailyCheckIn.
struct CheckInDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var sub
    @Query(sort: \CustomCheckInQuestion.createdAt) private var customQuestions: [CustomCheckInQuestion]
    @Query(sort: \SideEffectEntry.date) private var allSideEffects: [SideEffectEntry]
    @Query private var adherenceLogs: [MedAdherenceLog]
    @Query(sort: \UserMedication.startDate) private var userMedications: [UserMedication]

    let checkIn: DailyCheckIn
    /// Called when the user taps "Edit this check-in".
    /// If nil, the edit button presents DailyCheckInSheet directly.
    var onEdit: (() -> Void)? = nil

    @State private var showingEditSheet = false
    @State private var showingPaywall = false

    private let calendar = Calendar.current

    // MARK: - Derived data

    private var scaleAnswers: [CheckInAnswer] {
        checkIn.answers.filter { $0.checkInLevel != nil }
    }

    private var textAnswers: [CheckInAnswer] {
        checkIn.answers.filter { $0.checkInLevel == nil && !(($0.text ?? "").isEmpty) }
    }

    private var averageScore: Double? {
        let scores = scaleAnswers.compactMap { $0.checkInLevel?.numericValue }.map(Double.init)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private var sideEffectsForDate: [SideEffectEntry] {
        let cal = Calendar.current
        return allSideEffects.filter { cal.isDate($0.date, inSameDayAs: checkIn.date) }
    }

    /// Medications scheduled for the check-in's day, paired with taken/skipped status.
    private struct MedStatus: Identifiable {
        let id: UUID
        let name: String
        let dose: String
        let taken: Bool
        let skipped: Bool
        var status: String { skipped ? "Skipped" : taken ? "Taken" : "Unknown" }
    }

    private var medsForDate: [MedStatus] {
        let date = calendar.startOfDay(for: checkIn.date)
        let weekday = calendar.component(.weekday, from: date)
        let log = adherenceLogs.first { calendar.isDate($0.date, inSameDayAs: date) }
        let takenIDs  = Set(log?.takenMedIDs  ?? [])
        let skippedIDs = Set(log?.skippedMedIDs ?? [])

        return userMedications.compactMap { med in
            let startOK = calendar.startOfDay(for: med.startDate) <= date
            let endOK   = med.endDate.map { calendar.startOfDay(for: $0) >= date } ?? true
            guard startOK && endOK else { return nil }
            let days = med.scheduledDays.isEmpty ? [1,2,3,4,5,6,7] : med.scheduledDays
            guard days.contains(weekday) else { return nil }
            return MedStatus(
                id: med.id,
                name: med.medication.brandName,
                dose: med.currentDose,
                taken:   takenIDs.contains(med.id),
                skipped: skippedIDs.contains(med.id)
            )
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    scoreHeader
                    if !scaleAnswers.isEmpty {
                        scaleSection
                    }
                    if !textAnswers.isEmpty {
                        textSection
                    }
                    if let note = checkIn.note, !note.isEmpty {
                        noteSection(note: note)
                    }
                    let meds = medsForDate
                    if !meds.isEmpty {
                        medsSection(meds: meds)
                    }
                    if !sideEffectsForDate.isEmpty {
                        sideEffectsSection
                    }
                    editButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle(checkIn.date.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                DailyCheckInSheet(targetDate: checkIn.date)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
                    .environment(sub)
            }
        }
    }

    // MARK: - Score header

    private var scoreHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            if let avg = averageScore {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Overall")
                        .font(Theme.Font.heroLabel)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", avg))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("/ 5")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            } else {
                Text("No scores recorded")
                    .font(Theme.Font.sectionTitle)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            // Coloured ring showing the score visually
            if let avg = averageScore {
                scoreRing(avg)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                        center: .center
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private func scoreRing(_ avg: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.divider, lineWidth: 5)
                .frame(width: 60, height: 60)
            Circle()
                .trim(from: 0, to: avg / 5.0)
                .stroke(Theme.Palette.success, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-90))
            Text(String(format: "%.0f", avg))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }

    // MARK: - Scale answers

    private var scaleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your responses")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(scaleAnswers.enumerated()), id: \.element) { idx, answer in
                    if let level = answer.checkInLevel {
                        scaleRow(answer: answer, level: level)
                        if idx < scaleAnswers.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    private func scaleRow(answer: CheckInAnswer, level: CheckInLevel) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(labelFor(key: answer.questionKey))
                    .font(Theme.Font.bodyEmphasis)
                    .foregroundStyle(Theme.Palette.textPrimary)
                // Score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.Palette.divider)
                            .frame(height: 6)
                        Capsule()
                            .fill(barColor(for: level.numericValue))
                            .frame(width: geo.size.width * CGFloat(level.numericValue) / 5.0, height: 6)
                    }
                }
                .frame(height: 6)
            }
            Spacer(minLength: 12)
            Text("\(level.numericValue)/5")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(barColor(for: level.numericValue))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func barColor(for score: Int) -> Color {
        switch score {
        case 5:    return Theme.Palette.success
        case 4:    return Theme.Palette.success.opacity(0.75)
        case 3:    return Theme.Palette.attention
        case 1, 2: return Theme.Palette.negative
        default:   return Theme.Palette.textSecondary
        }
    }

    // MARK: - Text answers

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            ForEach(textAnswers, id: \.self) { answer in
                if let text = answer.text, !text.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(labelFor(key: answer.questionKey))
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Text(text)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                }
            }
        }
    }

    // MARK: - General note

    private func noteSection(note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("General note")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            Text(note)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    // MARK: - Medications

    private func medsSection(meds: [MedStatus]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Medications")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(meds.enumerated()), id: \.element.id) { idx, med in
                    HStack(spacing: 12) {
                        // Icon
                        Image(systemName: med.skipped ? "xmark.circle.fill" : med.taken ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.system(size: 20))
                            .foregroundStyle(med.skipped ? Theme.Palette.negative : med.taken ? Theme.Palette.success : Theme.Palette.textSecondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(med.name)
                                .font(Theme.Font.bodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(med.dose)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        Spacer()
                        Text(med.status)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(med.skipped ? Theme.Palette.negative : med.taken ? Theme.Palette.success : Theme.Palette.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((med.skipped ? Theme.Palette.negative : med.taken ? Theme.Palette.success : Theme.Palette.textSecondary).opacity(0.10))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if idx < meds.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    // MARK: - Side effects

    private var sideEffectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Side effects logged")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(sideEffectsForDate.enumerated()), id: \.element.id) { idx, se in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(se.label)
                                .font(Theme.Font.bodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            if let note = se.note, !note.isEmpty {
                                Text(note)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        Spacer()
                        Text(se.severity.displayName)
                            .font(Theme.Font.caption)
                            .foregroundStyle(severityColor(se.severity))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(severityColor(se.severity).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if idx < sideEffectsForDate.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    private func severityColor(_ severity: SideEffectSeverity) -> Color {
        switch severity {
        case .mild:     return Theme.Palette.attention
        case .moderate: return Theme.Palette.negative.opacity(0.85)
        case .severe:   return Theme.Palette.negative
        }
    }

    // MARK: - Edit button

    private var editButton: some View {
        Button {
            // Editing an existing check-in is a write — gate it for expired
            // users (H1). canWrite handles the cold-start window via cache.
            guard sub.canWrite else {
                showingPaywall = true
                return
            }
            if let onEdit {
                dismiss()
                onEdit()
            } else {
                showingEditSheet = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                Text("Edit this check-in")
            }
            .font(Theme.Font.bodyEmphasis)
            .foregroundStyle(Theme.Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .stroke(Theme.Palette.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func labelFor(key: String) -> String {
        if let std = StandardCheckInQuestion(rawValue: key) {
            return std.shortLabel
        }
        if let custom = customQuestions.first(where: { $0.storageKey == key }) {
            return custom.prompt
        }
        return "Note"
    }
}
