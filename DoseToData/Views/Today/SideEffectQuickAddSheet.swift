import SwiftUI
import SwiftData

struct SideEffectQuickAddSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    @State private var selectedLabel: String = ""
    @State private var customLabel: String = ""
    @State private var severity: SideEffectSeverity = .mild
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Add a side effect")
                        .font(Theme.Font.sectionTitle)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Common")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        FlowLayout(spacing: 8) {
                            ForEach(suggestedLabels, id: \.self) { label in
                                Button {
                                    selectedLabel = label
                                    customLabel = ""
                                } label: {
                                    Text(label)
                                        .font(Theme.Font.caption)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(selectedLabel == label ? Theme.Palette.primary : Color.white)
                                        .foregroundStyle(selectedLabel == label ? Color.white : Theme.Palette.textPrimary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(Theme.Palette.divider, lineWidth: selectedLabel == label ? 0 : 1)
                                        )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or type your own")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        TextField("Something else", text: $customLabel)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: customLabel) { _, newValue in
                                if !newValue.isEmpty { selectedLabel = "" }
                            }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Severity")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        HStack(spacing: 8) {
                            ForEach(SideEffectSeverity.allCases) { option in
                                Button {
                                    severity = option
                                } label: {
                                    Text(option.rawValue.capitalized)
                                        .font(Theme.Font.bodyEmphasis)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(severity == option ? Theme.Palette.primary : Color.white)
                                        .foregroundStyle(severity == option ? Color.white : Theme.Palette.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.Radius.button)
                                                .stroke(Theme.Palette.divider, lineWidth: severity == option ? 0 : 1)
                                        )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optional)")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        TextField("When, how bad, context", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        save()
                    } label: {
                        Text("Save")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(resolvedLabel.isEmpty)
                    .opacity(resolvedLabel.isEmpty ? 0.5 : 1)
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

    private var resolvedLabel: String {
        let custom = customLabel.trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? selectedLabel : custom
    }

    private var suggestedLabels: [String] {
        let fromMeds = Array(userMedications.prefix(6)).flatMap { $0.medication.commonSideEffects }
        let fallback = [
            "Appetite suppressed", "Insomnia", "Headache", "Anxiety", "Dry mouth",
            "Nausea", "Dizziness", "Fatigue", "Irritability"
        ]
        var seen = Set<String>()
        let merged = (fromMeds + fallback).filter { seen.insert($0).inserted }
        return Array(merged.prefix(12))
    }

    private func save() {
        let label = resolvedLabel
        guard !label.isEmpty else { return }
        let entry = SideEffectEntry(
            label: label,
            severity: severity,
            note: note.isEmpty ? nil : note
        )
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
