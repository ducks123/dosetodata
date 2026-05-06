import SwiftUI
import SwiftData

struct EditTestSheet: View {
    @Bindable var test: Test
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var watchingFor: String
    @State private var plannedEndDate: Date
    @State private var hasPlannedEnd: Bool
    @State private var showingEndConfirm = false
    @State private var showingDeleteConfirm = false

    init(test: Test) {
        self.test = test
        _name = State(initialValue: test.name)
        _watchingFor = State(initialValue: test.watchingFor)
        _plannedEndDate = State(initialValue: test.plannedEndDate ?? Calendar.current.date(byAdding: .day, value: 28, to: test.startDate) ?? Date())
        _hasPlannedEnd = State(initialValue: test.plannedEndDate != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    nameSection
                    watchingSection
                    endDateSection
                    if test.actualEndDate == nil {
                        endNowButton
                    }
                    deleteButton
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(Theme.Palette.background)
            .navigationTitle("Edit test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                }
            }
        }
        .confirmationDialog(
            "End test now?",
            isPresented: $showingEndConfirm
        ) {
            Button("End test today", role: .destructive) { endTestNow() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This marks the test as finished today. Its data stays in history.")
        }
        .confirmationDialog(
            "Delete this test?",
            isPresented: $showingDeleteConfirm
        ) {
            Button("Delete test", role: .destructive) { deleteTest() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The test is removed. Your medication events and check-ins are kept.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let medName = test.startEvent?.userMedication?.medication.brandName {
                Text(medName)
                    .font(Theme.Font.heroLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Text("Started \(test.startDate.formatted(date: .abbreviated, time: .omitted))")
                .font(Theme.Font.bodyEmphasis)
            if let end = test.actualEndDate {
                Text("Completed \(end.formatted(date: .abbreviated, time: .omitted))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            TextField("Name this test", text: $name)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.Palette.divider, lineWidth: 1))
        }
    }

    private var watchingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Watching for")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            TextField("e.g. Better focus at work", text: $watchingFor, axis: .vertical)
                .lineLimit(1...3)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.Palette.divider, lineWidth: 1))
        }
    }

    private var endDateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $hasPlannedEnd) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Planned end date")
                        .font(Theme.Font.bodyEmphasis)
                    Text("Turn off for an open-ended test.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .tint(Theme.Palette.primary)
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

            if hasPlannedEnd {
                HStack {
                    Text("Ends on")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Spacer()
                    DatePicker("Ends on", selection: $plannedEndDate, in: test.startDate..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
        }
    }

    private var endNowButton: some View {
        Button {
            showingEndConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                Text("End test now")
            }
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Delete test")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(Theme.Palette.negative)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.button)
                .stroke(Theme.Palette.negative.opacity(0.4), lineWidth: 1)
        )
    }

    private func save() {
        test.name = name.trimmingCharacters(in: .whitespaces)
        test.watchingFor = watchingFor
        test.plannedEndDate = hasPlannedEnd ? plannedEndDate : nil
        try? modelContext.save()
        dismiss()
    }

    private func endTestNow() {
        test.actualEndDate = Date()
        try? modelContext.save()
        dismiss()
    }

    private func deleteTest() {
        modelContext.delete(test)
        try? modelContext.save()
        dismiss()
    }
}
