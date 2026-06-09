import SwiftUI
import SwiftData

/// Bottom sheet that opens when the user taps a chart marker for a
/// medication change. Shows:
/// - The date + a one-line summary of what changed
/// - The "what are you watching for" note, if any
/// - A before/after table built by `MedChangeWindowAnalysis`
/// - A footer that explains the sample size, with copy from the agreed spec
/// - Delete action
struct MedChangeMarkerDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let event: MedChangeEvent
    /// Every other `MedChangeEvent` in the database — needed to compute
    /// the adjacent-change cap.
    let allEvents: [MedChangeEvent]
    /// Every `DailyCheckIn` — analyzer filters to the windows internally.
    let allCheckIns: [DailyCheckIn]

    @State private var showingDeleteConfirm = false

    private var analysis: MedChangeWindowAnalysis {
        MedChangeWindowAnalysis(
            event: AnalyzableEvent(id: event.id, date: event.date),
            allEvents: allEvents.map { AnalyzableEvent(id: $0.id, date: $0.date) },
            checkIns: allCheckIns.map { ci in
                AnalyzableCheckIn(
                    date: ci.date,
                    scaleAnswers: ci.answers.compactMap { a in
                        guard let level = a.checkInLevel else { return nil }
                        return AnalyzableScaleAnswer(
                            questionKey: a.questionKey,
                            numericLevel: level.numericValue
                        )
                    }
                )
            }
        )
    }

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
                    beforeAfterSection
                    sampleFooter
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
        VStack(alignment: .leading, spacing: 4) {
            Text("\(event.actions.count) change\(event.actions.count == 1 ? "" : "s")")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
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

    @ViewBuilder
    private var beforeAfterSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Before vs After")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            switch analysis.sampleSizeBand {
            case .none:
                notEnoughDataCard
            case .small, .normal:
                tableCard
            }
        }
    }

    private var notEnoughDataCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not enough data")
                .font(Theme.Font.bodyEmphasis)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("We need at least 2 check-ins on either side of this change to show a comparison.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var tableCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(analysis.rows.enumerated()), id: \.element.id) { (idx, row) in
                if idx > 0 {
                    Divider().padding(.horizontal, 14)
                }
                tableRow(row)
            }
        }
        .padding(.vertical, 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func tableRow(_ row: MedChangeWindowAnalysis.QuestionAverages) -> some View {
        HStack(spacing: 14) {
            Text(row.label)
                .font(Theme.Font.bodyEmphasis)
                .frame(width: 120, alignment: .leading)

            valueText(row.beforeMean)
                .frame(width: 50, alignment: .trailing)

            Image(systemName: "arrow.right")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Palette.textSecondary)

            valueText(row.afterMean)
                .frame(width: 50, alignment: .trailing)

            deltaArrow(before: row.beforeMean, after: row.afterMean)
                .frame(width: 22)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func valueText(_ value: Double?) -> some View {
        if let v = value {
            Text(String(format: "%.1f", v))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Palette.textPrimary)
        } else {
            Text("—")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    @ViewBuilder
    private func deltaArrow(before: Double?, after: Double?) -> some View {
        if let b = before, let a = after {
            let delta = a - b
            if delta > 0.05 {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Palette.success)
            } else if delta < -0.05 {
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Palette.negative)
            } else {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        } else {
            Color.clear.frame(width: 13, height: 13)
        }
    }

    @ViewBuilder
    private var sampleFooter: some View {
        switch analysis.sampleSizeBand {
        case .none:
            // Already covered by the "Not enough data" card.
            EmptyView()
        case .small:
            VStack(alignment: .leading, spacing: 4) {
                Text("Based on a small sample (\(analysis.beforeWindow.sampleSize) of \(analysis.beforeWindow.dayCount) days before, \(analysis.afterWindow.sampleSize) of \(analysis.afterWindow.dayCount) days after).")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("Log more days for a better picture.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.horizontal, 4)
        case .normal:
            Text("Based on \(analysis.beforeWindow.sampleSize) check-ins before and \(analysis.afterWindow.sampleSize) check-ins after.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.horizontal, 4)
        }
    }
}
