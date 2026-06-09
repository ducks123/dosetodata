import SwiftUI
import SwiftData

/// Bottom sheet that opens when the user taps a chart marker for a
/// medication change. Shows just the facts of what changed and the
/// note about what they're watching for — the chart line above the
/// markers IS the before/after comparison, so we don't render any
/// numeric "before vs after" analysis here.
struct MedChangeMarkerDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let event: MedChangeEvent

    @State private var showingDeleteConfirm = false
    @State private var showingEditSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    changesSection
                    if let watchingFor = event.watchingFor,
                       !watchingFor.trimmingCharacters(in: .whitespaces).isEmpty {
                        watchingForSection(text: watchingFor)
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .background(Theme.Palette.background)
            .navigationTitle(event.date.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Label("Edit this change", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete this change", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                LogMedChangeSheet(editing: event)
            }
            .confirmationDialog(
                "Delete this medication change?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(event)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the marker from your charts. Your check-in history isn't affected.")
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Text("\(event.actions.count) change\(event.actions.count == 1 ? "" : "s")")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.textSecondary)
    }

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(event.actions) { action in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(action.medication.category.pastelColor)
                            .frame(width: 32, height: 32)
                        Image(systemName: action.medication.category.iconSystemName)
                            .foregroundStyle(Theme.Palette.primary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(action.summaryLine)
                        .font(Theme.Font.bodyEmphasis)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
        }
    }

    private func watchingForSection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What you were watching for")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            Text("\u{201C}\(text)\u{201D}")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Palette.heroAccent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }
}
