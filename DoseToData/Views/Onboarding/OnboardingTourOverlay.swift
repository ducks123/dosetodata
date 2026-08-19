import SwiftUI
import Charts

/// UI pieces for the post-onboarding guided tour that runs inside the real
/// app (MainTabView owns the stage machine; see `UserPreferences.onboardingTourStage`).

// MARK: - Stage 1 banner (Today)

/// Nudge shown above the tab bar until the user saves their first check-in.
struct TourGuideBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.primary)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Palette.primary.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        .padding(.horizontal, 20)
    }
}

// MARK: - Tab tooltip (stages 2 and 3)

/// Small tooltip with a downward arrow, positioned above the tab bar and
/// horizontally aligned with the tab it points at.
struct TourTabTooltip: View {
    let text: String
    /// 0 = leading tab, 0.5 = center tab, 1 = trailing tab.
    let tabPosition: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Palette.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Theme.Palette.primary.opacity(0.35), radius: 8, y: 3)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Palette.primary)
                .offset(y: -2)
        }
        .frame(maxWidth: .infinity, alignment: tabAlignment)
        .padding(.horizontal, 40)
    }

    private var tabAlignment: Alignment {
        switch tabPosition {
        case ..<0.34:   return .leading
        case ..<0.67:   return .center
        default:        return .trailing
        }
    }
}

// MARK: - Insights example card (stage 4)

/// Shown over the real Insights tab: the user's actual first data point plus
/// a clearly-labeled example of what two weeks of tracking looks like.
///
/// Compliance note (Guideline 1.4.2): the grey line is generic EXAMPLE data,
/// dashed and muted, labeled as an example in the caption. It is deliberately
/// not anchored to the user's real value and must never be framed as a
/// forecast of their own trajectory.
struct TourInsightsCard: View {
    /// Average of today's scale answers (1 to 5), nil if the first check-in
    /// had no scale answers.
    let todayScore: Double?
    let onContinue: () -> Void

    private let exampleSeries: [(day: Int, value: Double)] = [
        (1, 2.6), (2, 2.9), (3, 2.7), (4, 3.1), (5, 3.3), (6, 3.0),
        (7, 3.4), (8, 3.2), (9, 3.6), (10, 3.8), (11, 3.5), (12, 3.9), (13, 4.0)
    ]
    private let exampleChangeDay = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your trends build here")
                .font(Theme.Font.sectionTitle)
            Text("Every check-in adds a point. When a medication changes, it gets marked on the chart so you can see what happened next.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            chart
                .frame(height: 150)

            Label("The grey line is example data. Your real trend builds one check-in at a time.",
                  systemImage: "info.circle")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onContinue) {
                Text("Continue")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 6)
        .padding(.horizontal, 20)
    }

    private var chart: some View {
        Chart {
            ForEach(exampleSeries, id: \.day) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Score", point.value),
                    series: .value("Series", "example")
                )
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                .interpolationMethod(.catmullRom)
            }

            RuleMark(x: .value("Day", exampleChangeDay))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .annotation(position: .top, alignment: .center) {
                    Text("Med change")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
                }

            if let score = todayScore {
                PointMark(
                    x: .value("Day", 0),
                    y: .value("Score", score)
                )
                .foregroundStyle(Theme.Palette.primary)
                .symbolSize(180)
                .annotation(position: .topTrailing, alignment: .leading) {
                    Text("You, today")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
        }
        .chartYScale(domain: 0.5...5.5)
        .chartXScale(domain: -0.5...14.5)
        .chartYAxis {
            AxisMarks(values: [1, 3, 5]) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: [0, 13]) { value in
                AxisValueLabel(anchor: value.as(Int.self) == 13 ? .topTrailing : .topLeading) {
                    if let day = value.as(Int.self) {
                        Text(day == 0 ? "Today" : "2 weeks")
                            .font(.system(size: 11))
                    }
                }
            }
        }
    }
}
