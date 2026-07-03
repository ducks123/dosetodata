import SwiftUI
import SwiftData

struct DailyCheckInSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(UserPreferences.self) private var prefs

    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]
    @Query(sort: \CustomCheckInQuestion.createdAt) private var customQuestions: [CustomCheckInQuestion]
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var allCheckIns: [DailyCheckIn]
    @Query(sort: \Test.startDate, order: .reverse) private var tests: [Test]
    @Query private var adherenceLogs: [MedAdherenceLog]
    @Query(sort: \SideEffectEntry.date) private var allSideEffects: [SideEffectEntry]

    let targetDate: Date

    init(targetDate: Date = Date()) {
        self.targetDate = targetDate
    }

    @State private var answers: [String: CheckInLevel] = [:]
    /// Free-form answers keyed by question storage key (for open-ended custom questions).
    @State private var textAnswers: [String: String] = [:]
    @State private var sideEffectsToday: [PendingSideEffect] = []
    @State private var note: String = ""
    @State private var showingAddQuestion = false
    @State private var showingAddSideEffect = false
    @State private var saveError: String? = nil
    /// UserMedication IDs the user has marked as skipped for this day.
    @State private var skippedMedIDs: Set<UUID> = []

    struct PendingSideEffect: Identifiable, Hashable {
        let id = UUID()
        var label: String
        var severity: SideEffectSeverity
        /// Set when this row was hydrated from an existing `SideEffectEntry`
        /// for the day being edited. Lets save() reconcile (keep/remove)
        /// instead of always inserting duplicates. Nil for freshly-added rows.
        var existingID: UUID? = nil
        /// Preserved from an existing entry (e.g. a quick-add note) so
        /// reconciliation never silently drops it.
        var note: String? = nil
    }

    private let calendar = Calendar.current

    private var isToday: Bool { calendar.isDateInToday(targetDate) }

    private var existingCheckIn: DailyCheckIn? {
        allCheckIns.first { calendar.isDate($0.date, inSameDayAs: targetDate) }
    }

    /// Side effects already recorded for the day being edited.
    private var existingSideEffectsForDate: [SideEffectEntry] {
        allSideEffects.filter { calendar.isDate($0.date, inSameDayAs: targetDate) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if !scheduledMedsForDate.isEmpty {
                        medStatusSection
                    }
                    standardQuestionsSection
                    customQuestionsSection
                    sideEffectsSection
                    noteSection
                }
                .padding(20)
                .padding(.bottom, 100)
            }
            .background(Theme.Palette.background)
            .navigationTitle(isToday ? "Today's check-in" : "Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
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
                .disabled(!hasAnyAnswer)
                .opacity(hasAnyAnswer ? 1 : 0.5)
            }
        }
        .sheet(isPresented: $showingAddSideEffect) {
            InlineSideEffectPicker { label, severity in
                sideEffectsToday.append(PendingSideEffect(label: label, severity: severity))
            }
            .presentationDetents([.medium])
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .sheet(isPresented: $showingAddQuestion) {
            AddCustomQuestionSheet(
                onAdd: { prompt, kind, leftAnchor, rightAnchor in
                    let q = CustomCheckInQuestion(
                        prompt: prompt,
                        kind: kind,
                        leftAnchor: leftAnchor,
                        rightAnchor: rightAnchor
                    )
                    modelContext.insert(q)
                    try? modelContext.save()
                },
                hiddenStandardQuestions: StandardCheckInQuestion.activeCases.filter {
                    prefs.hiddenStandardQuestionKeys.contains($0.rawValue)
                },
                onRestoreStandard: { q in
                    prefs.hiddenStandardQuestionKeys.remove(q.rawValue)
                }
            )
            .presentationDetents([.large])
        }
        .onAppear {
            if let existing = existingCheckIn {
                for answer in existing.answers {
                    if let level = answer.checkInLevel {
                        answers[answer.questionKey] = level
                    } else if let text = answer.text, !text.isEmpty {
                        textAnswers[answer.questionKey] = text
                    }
                }
                note = existing.note ?? ""
            }
            // Hydrate side effects already logged for this day so the user can
            // see and remove them — and so save() reconciles instead of
            // inserting duplicates (H4).
            if sideEffectsToday.isEmpty {
                sideEffectsToday = existingSideEffectsForDate.map {
                    PendingSideEffect(label: $0.label, severity: $0.severity, existingID: $0.id, note: $0.note)
                }
            }
            // Pre-fill med status from any notification quick-actions taken earlier.
            if let log = existingAdherenceLog {
                skippedMedIDs = Set(log.skippedMedIDs)
            }
        }
    }

    /// True when the user has entered *anything* — a scale answer or a non-empty
    /// text answer. Either counts as "logged for today".
    /// A check-in is worth saving if the user recorded ANY tracking data —
    /// a scale/text answer, a medication marked skipped, a side effect, or a
    /// note. Previously only scale/text answers counted, so an
    /// adherence-only / side-effect-only / note-only entry couldn't be saved.
    private var hasAnyAnswer: Bool {
        !answers.isEmpty
            || textAnswers.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || !skippedMedIDs.isEmpty
            || !sideEffectsToday.isEmpty
            || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(targetDate.formatted(.dateTime.weekday(.wide).month().day()))
                .font(Theme.Font.heroLabel)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(headerTitle)
                .font(Theme.Font.hero)
        }
    }

    private var headerTitle: String {
        if existingCheckIn == nil {
            return isToday ? "How was today?" : "How was this day?"
        }
        return isToday ? "Updating today's check-in" : "Updating check-in"
    }

    // MARK: - Medication status

    /// Active meds scheduled on the weekday of targetDate.
    private var scheduledMedsForDate: [UserMedication] {
        let weekday = calendar.component(.weekday, from: targetDate)
        return userMedications.filter { med in
            let startOK = calendar.startOfDay(for: med.startDate) <= calendar.startOfDay(for: targetDate)
            let endOK   = med.endDate.map { calendar.startOfDay(for: $0) >= calendar.startOfDay(for: targetDate) } ?? true
            guard startOK && endOK else { return false }
            let days = med.scheduledDays.isEmpty ? [1,2,3,4,5,6,7] : med.scheduledDays
            return days.contains(weekday)
        }
    }

    private var existingAdherenceLog: MedAdherenceLog? {
        adherenceLogs.first { calendar.isDate($0.date, inSameDayAs: targetDate) }
    }

    private var medStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isToday ? "Medications today" : "Medications on this day")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // "Took everything" quick row
                Button {
                    skippedMedIDs.removeAll()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(skippedMedIDs.isEmpty
                                      ? Theme.Palette.success
                                      : Theme.Palette.primary.opacity(0.10))
                                .frame(width: 32, height: 32)
                            Image(systemName: skippedMedIDs.isEmpty ? "checkmark" : "pills.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(skippedMedIDs.isEmpty ? Color.white : Theme.Palette.primary)
                        }
                        Text("Took everything")
                            .font(Theme.Font.bodyEmphasis)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        if skippedMedIDs.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Palette.success)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 60)

                // Individual med rows — tap to mark as skipped / restore
                ForEach(scheduledMedsForDate) { med in
                    let isSkipped = skippedMedIDs.contains(med.id)
                    Button {
                        if isSkipped {
                            skippedMedIDs.remove(med.id)
                        } else {
                            skippedMedIDs.insert(med.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isSkipped
                                          ? Theme.Palette.attention.opacity(0.15)
                                          : med.scheduleColor)
                                    .frame(width: 32, height: 32)
                                Image(systemName: med.medication.category.iconSystemName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isSkipped
                                                     ? Theme.Palette.attention
                                                     : Theme.Palette.primary)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(med.medication.brandName)
                                    .font(Theme.Font.bodyEmphasis)
                                    .foregroundStyle(isSkipped
                                                     ? Theme.Palette.textSecondary
                                                     : Theme.Palette.textPrimary)
                                    .strikethrough(isSkipped, color: Theme.Palette.textSecondary)
                                Text(isSkipped ? "Didn't take" : med.currentDose)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(isSkipped
                                                     ? Theme.Palette.attention
                                                     : Theme.Palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: isSkipped
                                  ? "xmark.circle.fill"
                                  : "checkmark.circle.fill")
                                .foregroundStyle(isSkipped
                                                 ? Theme.Palette.attention
                                                 : Theme.Palette.success)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                    }
                    .buttonStyle(.plain)

                    if med.id != scheduledMedsForDate.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: Theme.cardShadow.color, radius: Theme.cardShadow.radius,
                    x: Theme.cardShadow.x, y: Theme.cardShadow.y)
        }
    }

    /// Standard questions the user hasn't hidden, in `activeCases` order.
    private var visibleStandardQuestions: [StandardCheckInQuestion] {
        StandardCheckInQuestion.activeCases.filter {
            !prefs.hiddenStandardQuestionKeys.contains($0.rawValue)
        }
    }

    private var standardQuestionsSection: some View {
        VStack(spacing: 12) {
            ForEach(visibleStandardQuestions) { question in
                QuestionCard(
                    prompt: question.config.question,
                    leftAnchor: question.config.leftAnchor,
                    rightAnchor: question.config.rightAnchor,
                    selected: answers[question.rawValue],
                    onDelete: {
                        // Hiding the standard question doesn't delete any
                        // historical answers — past check-ins still render
                        // this question's data in CheckInDetailView. The
                        // user can restore it from the "Add question" sheet.
                        answers.removeValue(forKey: question.rawValue)
                        prefs.hiddenStandardQuestionKeys.insert(question.rawValue)
                    }
                ) { level in
                    answers[question.rawValue] = level
                }
            }
        }
    }

    private var visibleCustomQuestions: [CustomCheckInQuestion] {
        customQuestions.filter { q in
            guard let testID = q.testID else { return true }
            guard let test = tests.first(where: { $0.id == testID }) else { return false }
            let day = calendar.startOfDay(for: targetDate)
            let start = calendar.startOfDay(for: test.startDate)
            let end = test.actualEndDate ?? test.plannedEndDate ?? Date.distantFuture
            return day >= start && day <= calendar.startOfDay(for: end)
        }
    }

    private var customQuestionsSection: some View {
        VStack(spacing: 12) {
            ForEach(visibleCustomQuestions) { question in
                switch question.kind {
                case .scale:
                    // Custom scale questions now carry their own anchor labels (set in
                    // AddCustomQuestionSheet). Pre-migration rows have nil anchors, in
                    // which case the card simply omits the anchor row.
                    QuestionCard(
                        prompt: question.prompt,
                        leftAnchor: question.leftAnchor,
                        rightAnchor: question.rightAnchor,
                        selected: answers[question.storageKey],
                        onDelete: {
                            answers.removeValue(forKey: question.storageKey)
                            modelContext.delete(question)
                            try? modelContext.save()
                        }
                    ) { level in
                        answers[question.storageKey] = level
                    }
                case .text:
                    TextQuestionCard(
                        prompt: question.prompt,
                        text: Binding(
                            get: { textAnswers[question.storageKey] ?? "" },
                            set: { textAnswers[question.storageKey] = $0 }
                        ),
                        onDelete: {
                            textAnswers.removeValue(forKey: question.storageKey)
                            modelContext.delete(question)
                            try? modelContext.save()
                        }
                    )
                }
            }

            Button {
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
            Text(isToday ? "Side effects today" : "Side effects on this day")
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
            Text("Anything else? (optional)")
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

    private func finish() {
        let scaleEncoded = answers.map { (key, level) in
            CheckInAnswer.scale(questionKey: key, level: level)
        }
        let textEncoded = textAnswers.compactMap { (key, text) -> CheckInAnswer? in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return CheckInAnswer.text(questionKey: key, text: trimmed)
        }
        let encodedAnswers = scaleEncoded + textEncoded

        if let existing = existingCheckIn {
            existing.answers = encodedAnswers
            existing.note = note.isEmpty ? nil : note
        } else {
            let savedDate: Date = isToday ? Date() : calendar.startOfDay(for: targetDate)
            let ci = DailyCheckIn(
                date: savedDate,
                answers: encodedAnswers,
                note: note.isEmpty ? nil : note
            )
            modelContext.insert(ci)
        }

        // Reconcile side effects against the day being edited (H4):
        //  - new rows (no existingID) are inserted with the TARGET day's date,
        //    not today's, so editing a past check-in records them correctly;
        //  - existing rows the user removed are deleted;
        //  - existing rows kept are left untouched (preserving their note).
        let keptExistingIDs = Set(sideEffectsToday.compactMap { $0.existingID })
        let deleteIDs = Set(CheckInSideEffectReconciler.idsToDelete(
            existingForDate: existingSideEffectsForDate.map(\.id),
            keptExistingIDs: keptExistingIDs
        ))
        for entry in existingSideEffectsForDate where deleteIDs.contains(entry.id) {
            modelContext.delete(entry)
        }
        let sideEffectDate = CheckInSideEffectReconciler.sideEffectDate(
            forTargetDate: targetDate, now: Date(), calendar: calendar
        )
        for se in sideEffectsToday where se.existingID == nil {
            let entry = SideEffectEntry(
                date: sideEffectDate,
                label: se.label,
                severity: se.severity,
                note: se.note
            )
            modelContext.insert(entry)
        }

        // Persist med adherence for this day. Idempotent upsert collapses any
        // duplicate same-day logs (e.g. one created by a notification quick
        // action on another context) into one before we write (M3).
        if !scheduledMedsForDate.isEmpty {
            let takenIDs = scheduledMedsForDate.map(\.id).filter { !skippedMedIDs.contains($0) }
            let log = AdherenceLogStore.upsert(for: targetDate, in: modelContext)
            log.takenMedIDs = takenIDs
            log.skippedMedIDs = Array(skippedMedIDs)
        }

        do {
            try modelContext.save()
        } catch {
            saveError = "Couldn't save your check-in. Please try again."
            return
        }

        // Celebrate every successful log, past / today / future. Dismiss
        // the sheet first so the confetti is visible on TodayView, then
        // trigger the burst after the dismiss animation. Streak milestone
        // notifications only fire for today's logs (currentStreak only
        // counts streaks anchored at today/yesterday anyway).
        let appStateRef = appState
        let datesForStreak = allCheckIns.map { $0.date } + [Date()]
        let wasToday = isToday
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appStateRef.confettiTrigger = UUID()
            if wasToday {
                let streak = AppState.currentStreak(from: datesForStreak)
                Task {
                    await ReminderManager.shared.fireMilestoneNotificationIfNeeded(streak: streak)
                }
            }
        }
    }
}

private struct QuestionCard: View {
    let prompt: String
    /// Label shown under value 1. Represents the "harder / more symptomatic" end.
    let leftAnchor: String?
    /// Label shown under value 5. Represents the "easier / better" end.
    let rightAnchor: String?
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
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ForEach(CheckInLevel.allCases) { level in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                // Anchor row: left anchor under "1", right anchor under "5".
                // Only rendered when both anchors are provided (standard questions);
                // custom questions currently omit this row.
                if let leftAnchor, let rightAnchor {
                    HStack {
                        Text(leftAnchor)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Spacer()
                        Text(rightAnchor)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .padding(.horizontal, 4)
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

/// Card for an open-ended custom question — prompt plus a multi-line text field.
private struct TextQuestionCard: View {
    let prompt: String
    @Binding var text: String
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            TextEditor(text: $text)
                .padding(8)
                .frame(minHeight: 80)
                .background(Theme.Palette.background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .stroke(Theme.Palette.divider, lineWidth: 1)
                )
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

/// Sheet presented from the check-in view for creating a new custom question.
///
/// UX goals:
/// - Teach the 5-is-better scoring convention inside the flow itself (not a docs page).
/// - Ask for the two anchor labels up front instead of leaving the scale unlabeled.
/// - Show a live preview so the user sees how the question will render on check-in.
/// - Soft-warn when the anchors look flipped (e.g. "Good" on left, "Anxious" on right).
/// - Offer a one-tap Swap to reverse the labels if the warning is right.
///
/// Anchors are required for scale kind; free-text questions don't use them.
struct AddCustomQuestionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var prompt: String = ""
    @State private var kind: CheckInQuestionKind = .scale
    @State private var leftAnchor: String = ""
    @State private var rightAnchor: String = ""

    /// Called with the trimmed prompt + kind + trimmed anchors when the user taps Add.
    /// For text-kind questions both anchors are nil.
    let onAdd: (_ prompt: String, _ kind: CheckInQuestionKind, _ leftAnchor: String?, _ rightAnchor: String?) -> Void

    /// Standard questions the user has hidden — when non-empty, rendered as
    /// a "Restore" section at the top of this sheet so the user can bring
    /// them back without leaving the add-question flow.
    var hiddenStandardQuestions: [StandardCheckInQuestion] = []
    /// Called when the user taps "Restore" on a hidden standard question.
    var onRestoreStandard: ((StandardCheckInQuestion) -> Void)? = nil

    private var trimmedPrompt: String { prompt.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedLeft: String { leftAnchor.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedRight: String { rightAnchor.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Enable Add when the prompt is filled and — for scale questions — both anchors are.
    private var canSave: Bool {
        guard !trimmedPrompt.isEmpty else { return false }
        switch kind {
        case .text:  return true
        case .scale: return !trimmedLeft.isEmpty && !trimmedRight.isEmpty
        }
    }

    /// True when the heuristic thinks the anchors are probably reversed.
    private var looksBackwards: Bool {
        guard kind == .scale, !trimmedLeft.isEmpty, !trimmedRight.isEmpty else { return false }
        return CheckInAnchorHeuristic.looksBackwards(left: trimmedLeft, right: trimmedRight)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !hiddenStandardQuestions.isEmpty {
                        restoreSection
                    }
                    answerTypePicker
                    questionField

                    if kind == .scale {
                        anchorFields
                        conventionCallout
                        if looksBackwards { backwardsWarning }
                        previewSection
                    }

                    footerNote
                }
                .padding(20)
            }
            .background(Theme.Palette.background)
            .navigationTitle("Add a question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        guard canSave else { return }
                        switch kind {
                        case .scale:
                            onAdd(trimmedPrompt, .scale, trimmedLeft, trimmedRight)
                        case .text:
                            onAdd(trimmedPrompt, .text, nil, nil)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: Sections

    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Restore a removed question")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            VStack(spacing: 8) {
                ForEach(hiddenStandardQuestions) { q in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(q.shortLabel)
                                .font(Theme.Font.bodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(q.config.question)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Restore") {
                            onRestoreStandard?(q)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.primary)
                    }
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
            }
        }
    }

    private var answerTypePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Answer type")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            HStack(spacing: 8) {
                ForEach(CheckInQuestionKind.allCases) { option in
                    Button {
                        kind = option
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.displayName)
                                .font(Theme.Font.bodyEmphasis)
                            Text(hint(for: option))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(kind == option ? Color.white.opacity(0.8) : Theme.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(kind == option ? Theme.Palette.primary : Color.white)
                        .foregroundStyle(kind == option ? Color.white : Theme.Palette.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.button)
                                .stroke(Theme.Palette.divider, lineWidth: kind == option ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var questionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Question")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            TextField("e.g. How is your sleep?", text: $prompt, axis: .vertical)
                .lineLimit(1...3)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(Theme.Palette.divider, lineWidth: 1)
                )
        }
    }

    /// Two side-by-side fields whose horizontal position matches where their labels
    /// will show up in the real scale row (left = under "1", right = under "5").
    /// A small "Swap labels" link in the header lets the user flip them in one tap.
    private var anchorFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Scale labels")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Button {
                    let tmp = leftAnchor
                    leftAnchor = rightAnchor
                    rightAnchor = tmp
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                        Text("Swap labels")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.primary)
                }
                .buttonStyle(.plain)
                .disabled(trimmedLeft.isEmpty && trimmedRight.isEmpty)
                .opacity((trimmedLeft.isEmpty && trimmedRight.isEmpty) ? 0.4 : 1)
            }
            .padding(.horizontal, 4)

            HStack(alignment: .top, spacing: 10) {
                anchorField(
                    caption: "1 means (harder)",
                    placeholder: "e.g. Poor",
                    text: $leftAnchor
                )
                anchorField(
                    caption: "5 means (better)",
                    placeholder: "e.g. Great",
                    text: $rightAnchor
                )
            }
        }
    }

    private func anchorField(caption: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            TextField(placeholder, text: text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(Theme.Palette.divider, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }

    /// Gentle blue callout that appears once the user has switched to scale mode.
    /// Teaches the convention without being loud.
    private var conventionCallout: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.up.right.circle.fill")
                .foregroundStyle(Theme.Palette.primary)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("Keep 1 as the harder state, 5 as the better.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("That way, higher averages always mean a better day.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.heroAccent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
    }

    /// Amber warning only shown when `CheckInAnchorHeuristic` thinks the anchors are flipped.
    /// Non-blocking — Add button stays enabled so a determined user can override.
    private var backwardsWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Palette.attention)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("These look flipped.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("1 should describe the harder state and 5 the better state. Tap Swap labels.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.attention.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
    }

    /// Read-only preview using the same visual language as the live QuestionCard.
    /// Renders the placeholder prompt if the user hasn't typed one yet, so the
    /// layout doesn't jump when they start typing.
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            QuestionPreviewCard(
                prompt: trimmedPrompt.isEmpty ? "How is your …?" : trimmedPrompt,
                leftAnchor: trimmedLeft.isEmpty ? nil : trimmedLeft,
                rightAnchor: trimmedRight.isEmpty ? nil : trimmedRight
            )
        }
    }

    private var footerNote: some View {
        Text("This question appears on every future check-in. Remove it anytime from the question card's menu.")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    private func hint(for kind: CheckInQuestionKind) -> String {
        switch kind {
        case .scale: return "Tap 1–5 each day."
        case .text:  return "Type a note each day."
        }
    }
}

/// Non-interactive preview of a scale question. Mirrors `QuestionCard` so the user
/// sees exactly what they'll get on their daily check-in. Kept as a separate view
/// (vs reusing QuestionCard in a "read-only" mode) so the preview's tappability
/// can't be confused with the real thing.
private struct QuestionPreviewCard: View {
    let prompt: String
    let leftAnchor: String?
    let rightAnchor: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt)
                .font(Theme.Font.bodyEmphasis)
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ForEach(CheckInLevel.allCases) { level in
                        Text(level.displayName)
                            .font(Theme.Font.bodyEmphasis)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                    .stroke(Theme.Palette.divider, lineWidth: 1)
                            )
                    }
                }
                if let leftAnchor, let rightAnchor {
                    HStack {
                        Text(leftAnchor)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Spacer()
                        Text(rightAnchor)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .padding(.horizontal, 4)
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
        // Make it obvious this is a preview, not interactive.
        .allowsHitTesting(false)
    }
}
