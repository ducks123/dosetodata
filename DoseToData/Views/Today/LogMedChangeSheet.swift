import SwiftUI
import SwiftData

/// The single-screen sheet for logging a medication change. Replaces the
/// multi-step CreateTestSheet flow. One event can bundle multiple
/// `MedAction`s — matches how psychiatrists usually deliver changes at an
/// appointment.
struct LogMedChangeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Medication.brandName) private var libraryMeds: [Medication]
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    /// When non-nil, this sheet edits the given event in place instead of
    /// inserting a new one. The user's date / actions / "watching for"
    /// note are hydrated from the event on first appear.
    var editing: MedChangeEvent? = nil

    @State private var date: Date = Date()
    @State private var actionDrafts: [ActionDraft] = [ActionDraft()]
    @State private var watchingFor: String = ""
    @State private var showingMedPickerForDraftID: UUID? = nil
    /// One-time hydration guard so swapping date/text fields doesn't
    /// overwrite user edits when the view re-renders.
    @State private var didHydrateFromEditingEvent = false

    private var isEditing: Bool { editing != nil }

    /// Mutable working copy of a MedAction while the sheet is open. Converted
    /// into a real MedAction on save. Keeps the SwiftData model out of
    /// half-built UI state.
    struct ActionDraft: Identifiable {
        let id = UUID()
        var medication: Medication? = nil
        var kind: MedAction.Kind = .start
        var dose: String = ""
        var previousDose: String = ""
    }

    private var activeMeds: [UserMedication] {
        userMedications.filter { $0.endDate == nil }
    }

    /// A drafted action is complete enough to save: it has a medication, and
    /// Start / Dose change also have a (new) dose. Stop needs nothing more.
    /// (Prevents saving an ambiguous change — empty starting dose, or a
    /// "Dose change" with no new dose — that makes charts / clinician notes
    /// useless. #16)
    private func draftIsComplete(_ draft: ActionDraft) -> Bool {
        guard draft.medication != nil else { return false }
        switch draft.kind {
        case .start, .doseChange:
            return !draft.dose.trimmingCharacters(in: .whitespaces).isEmpty
        case .stop:
            return true
        }
    }

    private var canSave: Bool {
        // At least one medication picked, and every picked-medication row is
        // complete. Rows with no medication (e.g. a trailing "add another"
        // row) are ignored.
        let withMedication = actionDrafts.filter { $0.medication != nil }
        return !withMedication.isEmpty && withMedication.allSatisfy(draftIsComplete)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isEditing {
                        editScopeNote
                    }
                    dateSection
                    changesSection
                    addAnotherButton
                    watchingForSection
                    summaryPreview
                }
                .padding(20)
                .padding(.bottom, 80)
            }
            .background(Theme.Palette.background)
            .navigationTitle(isEditing ? "Edit medication change" : "Log medication change")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                hydrateFromEditingEventIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                } label: {
                    Text(isEditing ? "Save changes" : "Save medication change")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.Palette.background.opacity(0.96))
            }
        }
        .sheet(item: Binding(
            get: { showingMedPickerForDraftID.map { MedPickerTarget(draftID: $0) } },
            set: { showingMedPickerForDraftID = $0?.draftID }
        )) { target in
            MedPickerSheet(
                draft: bindingForDraft(id: target.draftID),
                libraryMeds: libraryMeds,
                activeMeds: activeMeds
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Sections

    /// Shown only when editing an existing event. Edits update the timeline
    /// marker but intentionally do NOT re-apply start/stop/dose actions to the
    /// current medication list (avoids double-applying). Tell the user so the
    /// timeline and med list don't silently diverge (M1).
    private var editScopeNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Theme.Palette.textSecondary)
                .font(.system(size: 14))
            Text("Editing updates this timeline entry only. It won't change your current medication list — manage that in Schedule → Edit medications.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.heroAccent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("When")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Changes")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            VStack(spacing: 12) {
                ForEach($actionDrafts) { $draft in
                    actionCard(draft: $draft)
                }
            }
        }
    }

    @ViewBuilder
    private func actionCard(draft: Binding<ActionDraft>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Med picker trigger.
            //
            // Two visual states:
            // - **No medication selected** → renders as a prominent filled
            //   primary-color CTA button. Earlier flat-link styling was
            //   getting skipped over by users so this state needs to read
            //   unambiguously as "tap me."
            // - **Medication selected** → renders as a quieter row showing
            //   the picked med with a chevron, so the row makes room for
            //   the kind picker and dose fields below.
            Button {
                showingMedPickerForDraftID = draft.wrappedValue.id
            } label: {
                if let med = draft.wrappedValue.medication {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(med.category.pastelColor)
                                .frame(width: 32, height: 32)
                            Image(systemName: med.category.iconSystemName)
                                .foregroundStyle(Theme.Palette.primary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(med.brandName)
                                .font(Theme.Font.bodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(med.genericName)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text("Choose a medication")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Palette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
            }
            .buttonStyle(.plain)

            // Kind picker
            HStack(spacing: 8) {
                ForEach(MedAction.Kind.allCases) { k in
                    Button {
                        draft.wrappedValue.kind = k
                    } label: {
                        Text(k.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(draft.wrappedValue.kind == k ? Theme.Palette.primary : Color.white)
                            .foregroundStyle(draft.wrappedValue.kind == k ? Color.white : Theme.Palette.textPrimary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Theme.Palette.divider, lineWidth: draft.wrappedValue.kind == k ? 0 : 1))
                    }
                }
            }

            // Dose inputs depending on kind
            switch draft.wrappedValue.kind {
            case .start:
                doseField(label: "Dose", value: draft.dose, placeholder: "e.g. 10mg")
            case .doseChange:
                HStack(spacing: 12) {
                    doseField(label: "Previous", value: draft.previousDose, placeholder: "e.g. 300mg")
                    doseField(label: "New", value: draft.dose, placeholder: "e.g. 150mg")
                }
            case .stop:
                EmptyView()
            }

            // Inline hint when a medication is picked but its required dose is
            // still blank, so the user knows why Save is disabled (#16).
            if draft.wrappedValue.medication != nil,
               draft.wrappedValue.kind != .stop,
               draft.wrappedValue.dose.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(draft.wrappedValue.kind == .start
                     ? "Enter a dose to save this change."
                     : "Enter the new dose to save this change.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.negative)
            }

            // Remove row button (only if more than one)
            if actionDrafts.count > 1 {
                Button(role: .destructive) {
                    if let idx = actionDrafts.firstIndex(where: { $0.id == draft.wrappedValue.id }) {
                        actionDrafts.remove(at: idx)
                    }
                } label: {
                    Label("Remove this change", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func doseField(label: String, value: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            TextField(placeholder, text: value)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.Palette.divider, lineWidth: 1))
        }
    }

    private var addAnotherButton: some View {
        Button {
            actionDrafts.append(ActionDraft())
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("Add another change")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.Palette.primary)
        }
        .padding(.top, 2)
    }

    private var watchingForSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What are you watching for? (optional)")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            TextField(
                "e.g. Whether my afternoon focus improves and side effects ease up",
                text: $watchingFor,
                axis: .vertical
            )
            .lineLimit(3...6)
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private var summaryPreview: some View {
        let filled = actionDrafts.filter { $0.medication != nil }
        if !filled.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Summary preview")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.leading, 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text(date.formatted(date: .abbreviated, time: .omitted) + " · \(filled.count) change\(filled.count == 1 ? "" : "s")")
                        .font(Theme.Font.bodyEmphasis)
                    ForEach(filled) { draft in
                        if let summary = draftSummary(draft) {
                            Text(summary)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
                .padding(14)
                .background(Theme.Palette.heroAccent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
            .padding(.top, 10)
        }
    }

    private func draftSummary(_ draft: ActionDraft) -> String? {
        guard let med = draft.medication else { return nil }
        let name = med.brandName
        switch draft.kind {
        case .start:
            let dose = draft.dose.trimmingCharacters(in: .whitespaces)
            return dose.isEmpty ? "\(name) + Started" : "\(name) + Started \(dose)"
        case .stop:
            return "\(name) − Stopped"
        case .doseChange:
            let prev = draft.previousDose.trimmingCharacters(in: .whitespaces)
            let new = draft.dose.trimmingCharacters(in: .whitespaces)
            switch (prev.isEmpty, new.isEmpty) {
            case (false, false): return "\(name) ↕ \(prev) → \(new)"
            case (true, false):  return "\(name) ↕ \(new)"
            default:             return "\(name) ↕ Dose change"
            }
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedWatchingFor = watchingFor.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil
            : watchingFor.trimmingCharacters(in: .whitespaces)

        let event: MedChangeEvent
        if let existing = editing {
            // EDIT mode — mutate fields in place and replace all child
            // actions. We deliberately DON'T re-run applyToUserMedication
            // for edits: it'd double-apply (e.g. a second "Start" would
            // create a duplicate UserMedication row) and there's no clean
            // undo for the prior application. If the user changes the kind
            // or dose of an existing action they can manually fix their
            // med list afterward.
            existing.date = date
            existing.watchingFor = trimmedWatchingFor
            for old in existing.actions {
                modelContext.delete(old)
            }
            event = existing
        } else {
            event = MedChangeEvent(date: date, watchingFor: trimmedWatchingFor)
            modelContext.insert(event)
        }

        for draft in actionDrafts {
            guard let med = draft.medication else { continue }
            let action = MedAction(
                medication: med,
                kind: draft.kind,
                dose: draft.dose.trimmingCharacters(in: .whitespaces).isEmpty ? nil : draft.dose,
                previousDose: draft.previousDose.trimmingCharacters(in: .whitespaces).isEmpty ? nil : draft.previousDose
            )
            action.event = event
            modelContext.insert(action)

            // Auto-update underlying UserMedication only when CREATING a
            // new event (see comment above for the edit-mode rationale).
            if !isEditing {
                applyToUserMedication(med: med, draft: draft, eventDate: date)
            }
        }

        do {
            try modelContext.save()
        } catch {
            // Save failed — leave the sheet open so the user can retry.
            return
        }

        dismiss()
    }

    /// Hydrate the draft state from `editing` once per sheet presentation.
    /// Called from a `.task` so it runs after init but before the user
    /// starts interacting with fields.
    private func hydrateFromEditingEventIfNeeded() {
        guard let event = editing, !didHydrateFromEditingEvent else { return }
        didHydrateFromEditingEvent = true
        date = event.date
        watchingFor = event.watchingFor ?? ""
        let drafts: [ActionDraft] = event.actions.map { action in
            ActionDraft(
                medication: action.medication,
                kind: action.kind,
                dose: action.dose ?? "",
                previousDose: action.previousDose ?? ""
            )
        }
        // Always show at least one row so the user has something to edit
        // if the event happened to have no actions (shouldn't happen, but
        // defensive).
        actionDrafts = drafts.isEmpty ? [ActionDraft()] : drafts
    }

    private func applyToUserMedication(med: Medication, draft: ActionDraft, eventDate: Date) {
        switch draft.kind {
        case .start:
            // Create a new UserMedication record for this med, with the
            // event date as its startDate. If the user is already on this
            // med (an active record exists), leave it alone — they may be
            // logging a historical retroactive start.
            let alreadyActive = userMedications.contains { $0.medication.id == med.id && $0.endDate == nil }
            if !alreadyActive {
                let userMed = UserMedication(
                    medication: med,
                    currentDose: draft.dose.trimmingCharacters(in: .whitespaces),
                    startDate: eventDate
                )
                modelContext.insert(userMed)
            }
        case .stop:
            // End the active UserMedication for this med, if any, and stop its
            // reminders so a stopped med doesn't keep notifying (H2).
            if let active = userMedications.first(where: { $0.medication.id == med.id && $0.endDate == nil }) {
                active.endDate = eventDate
                let stoppedID = active.id
                Task { await ReminderManager.shared.clearReminders(for: stoppedID) }
            }
        case .doseChange:
            if let active = userMedications.first(where: { $0.medication.id == med.id && $0.endDate == nil }) {
                let newDose = draft.dose.trimmingCharacters(in: .whitespaces)
                if !newDose.isEmpty {
                    active.currentDose = newDose
                    // Reschedule so the notification body shows the new dose,
                    // not the old one (H2). scheduleReminders clears first.
                    if active.remindersEnabled && !active.scheduledTimes.isEmpty {
                        let updated = active
                        Task { await ReminderManager.shared.scheduleReminders(for: updated) }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private struct MedPickerTarget: Identifiable {
        let draftID: UUID
        var id: UUID { draftID }
    }

    private func bindingForDraft(id: UUID) -> Binding<ActionDraft> {
        guard let idx = actionDrafts.firstIndex(where: { $0.id == id }) else {
            return .constant(ActionDraft())
        }
        return $actionDrafts[idx]
    }
}

// MARK: - MedPickerSheet

/// Library + active-meds picker presented when the user taps "Choose a
/// medication" on an action card. Lets the user pick from their library
/// (for Start) or their currently-active meds (for Stop / Dose change).
private struct MedPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: LogMedChangeSheet.ActionDraft
    let libraryMeds: [Medication]
    let activeMeds: [UserMedication]

    @State private var searchText: String = ""

    private var filteredLibrary: [Medication] {
        guard !searchText.isEmpty else { return libraryMeds }
        let q = searchText.lowercased()
        return libraryMeds.filter {
            $0.brandName.lowercased().contains(q) || $0.genericName.lowercased().contains(q)
        }
    }

    private var filteredActive: [UserMedication] {
        guard !searchText.isEmpty else { return activeMeds }
        let q = searchText.lowercased()
        return activeMeds.filter {
            $0.medication.brandName.lowercased().contains(q) ||
            $0.medication.genericName.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchField
                    if draft.kind != .start && !filteredActive.isEmpty {
                        section(title: "Currently taking") {
                            ForEach(filteredActive) { userMed in
                                medRow(userMed.medication) {
                                    select(userMed.medication)
                                }
                            }
                        }
                    }
                    section(title: draft.kind == .start ? "Medications" : "From library") {
                        ForEach(filteredLibrary.prefix(searchText.isEmpty ? 12 : 30)) { med in
                            medRow(med) {
                                select(med)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.Palette.background)
            .navigationTitle("Choose a medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Palette.textSecondary)
            TextField("Search medications", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.Palette.divider, lineWidth: 1))
    }

    @ViewBuilder
    private func section<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            content()
        }
    }

    private func medRow(_ med: Medication, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(med.category.pastelColor)
                        .frame(width: 36, height: 36)
                    Image(systemName: med.category.iconSystemName)
                        .foregroundStyle(Theme.Palette.primary)
                        .font(.system(size: 14, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(med.brandName)
                        .font(Theme.Font.bodyEmphasis)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("\(med.genericName) · \(med.medClass)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }

    private func select(_ med: Medication) {
        draft.medication = med
        // Prefill "Previous" dose for a dose-change action if we know the
        // user's current dose for this med.
        if draft.kind == .doseChange, draft.previousDose.isEmpty {
            if let active = activeMeds.first(where: { $0.medication.id == med.id }) {
                draft.previousDose = active.currentDose
            }
        }
        dismiss()
    }
}
