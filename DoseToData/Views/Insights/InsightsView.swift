import SwiftUI
import SwiftData
import Charts

enum InsightsRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:   return "Day"
        case .week:  return "Week"
        case .month: return "Month"
        case .year:  return "Year"
        }
    }
}

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var allCheckIns: [DailyCheckIn]
    @Query(sort: \Test.startDate, order: .reverse) private var tests: [Test]
    @Query(sort: \CustomCheckInQuestion.createdAt) private var customQuestions: [CustomCheckInQuestion]
    @Query private var adherenceLogs: [MedAdherenceLog]
    @Query(sort: \MedChangeEvent.date, order: .reverse) private var medChangeEvents: [MedChangeEvent]

    /// Event currently shown in the marker detail sheet (tap target). Nil
    /// when no marker is selected.
    @State private var selectedMedChangeEvent: MedChangeEvent? = nil

    /// Whether to render the medication-change markers + chips. Only on Day
    /// and Week — at Month/Year granularity multiple changes collapse to the
    /// same bucket position and stack up at the right edge, which looks
    /// broken. Coarse ranges hide them entirely.
    private var showMarkers: Bool {
        range == .day || range == .week
    }

    /// Medication-change events that belong in the currently visible chart
    /// window. Filtered to `scopedRange` so we don't render chips/markers for
    /// events outside the window, and empty unless `showMarkers`. Both the
    /// `RuleMark`s and the chip row use this (H3).
    private var visibleMedChangeEvents: [MedChangeEvent] {
        guard showMarkers else { return [] }
        let (start, end) = scopedRange
        return medChangeEvents.filter { $0.date >= start && $0.date <= end }
    }

    /// X position for a medication-change marker. Snaps the event date to the
    /// same bucket the score series uses, so a change logged today (at a
    /// non-midnight time) or mid-current-week lands inside the clamped chart
    /// domain instead of falling off the right edge (H3).
    private func markerX(for event: MedChangeEvent) -> Date {
        bucketKey(for: event.date)
    }

    /// Horizontal scrollable row of medication-change marker chips rendered
    /// below each chart. The chart shows a dashed vertical line at each
    /// `MedChangeEvent.date`; the chip row provides the tap target (Swift
    /// Charts' `RuleMark` annotations aren't reliably tappable inside the
    /// existing drag-selection gesture). Hidden when the user has no
    /// events. Tapping a chip opens the marker detail sheet.
    @ViewBuilder
    private var medChangeMarkerChips: some View {
        if !visibleMedChangeEvents.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleMedChangeEvents) { event in
                        Button {
                            selectedMedChangeEvent = event
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pill.fill")
                                    .font(.system(size: 10))
                                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Theme.Palette.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.Palette.primary.opacity(0.10))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    @State private var range: InsightsRange = .day
    @State private var windowOffset: Int = 0        // 0 → [Day,Week,Month]  1 → [Week,Month,Year]
    @State private var selectedTestID: UUID? = nil
    @State private var enabledStandardKeys: Set<String> = Set(StandardCheckInQuestion.activeCases.map { $0.rawValue })
    @State private var enabledCustomKeys: Set<String> = []
    @State private var showingAddGraph = false
    @State private var chartSelectedKey: String? = nil
    @State private var chartSelectedDate: Date? = nil
    @State private var viewingCheckInFromChart: DailyCheckIn? = nil

    private let calendar = AppCalendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if allCheckIns.isEmpty {
                        insightsEmptyState
                    } else {
                        scopeSection
                        currentStatusCard
                        chartsSection
                        addGraphButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            // NOTE: removed the global horizontal-swipe-to-switch-range
            // gesture. It conflicted with the horizontal med-change chip
            // scroll rows under each chart — swiping the chips accidentally
            // changed the Day/Week/Month/Year range. The segmented control
            // and < > arrows at the top remain the way to change range.
        }
        .sheet(isPresented: $showingAddGraph) {
            AddGraphSheet(
                standardEnabled: $enabledStandardKeys,
                customEnabled: $enabledCustomKeys,
                customQuestions: customQuestions,
                tests: tests
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $viewingCheckInFromChart) { ci in
            CheckInDetailView(checkIn: ci)
        }
        .sheet(item: $selectedMedChangeEvent) { event in
            MedChangeMarkerDetailSheet(event: event)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            consumePendingTest()
        }
        .onChange(of: appState.pendingInsightsTestID) { _, _ in
            consumePendingTest()
        }
    }

    private func consumePendingTest() {
        if let pending = appState.pendingInsightsTestID {
            selectedTestID = pending
            appState.pendingInsightsTestID = nil
        }
    }

    // MARK: Empty state

    private var insightsEmptyState: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.primary.opacity(0.10))
                        .frame(width: 88, height: 88)
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(Theme.Palette.primary)
                }

                VStack(spacing: 8) {
                    Text("Your insights will appear here")
                        .font(Theme.Font.sectionTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Complete your first daily check-in on the Today tab. After a few days you'll start seeing trends, scores, and patterns.")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Scope

    // MARK: Window helpers

    private let windowSize = 3
    private var allRanges: [InsightsRange] { InsightsRange.allCases }
    private var maxWindowOffset: Int { allRanges.count - windowSize }   // = 1

    private var visibleRanges: [InsightsRange] {
        Array(allRanges[windowOffset..<(windowOffset + windowSize)])
    }

    /// Slide the visible window forward (shows Year, hides Day).
    private func slideWindowForward() {
        guard windowOffset < maxWindowOffset else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            windowOffset += 1
            // If the current selection scrolled off the left edge, snap it in.
            if let idx = allRanges.firstIndex(of: range), idx < windowOffset {
                range = allRanges[windowOffset]
            }
        }
    }

    /// Slide the visible window backward (shows Day, hides Year).
    private func slideWindowBackward() {
        guard windowOffset > 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            windowOffset -= 1
            // If the current selection scrolled off the right edge, snap it in.
            if let idx = allRanges.firstIndex(of: range), idx >= windowOffset + windowSize {
                range = allRanges[windowOffset + windowSize - 1]
            }
        }
    }

    /// Advance the active range (swipe left). Also keeps the window in sync.
    private func advanceRange() {
        guard let idx = allRanges.firstIndex(of: range), idx + 1 < allRanges.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            range = allRanges[idx + 1]
            if idx + 1 >= windowOffset + windowSize {
                windowOffset = min(idx + 2 - windowSize, maxWindowOffset)
            }
        }
    }

    /// Retreat the active range (swipe right). Also keeps the window in sync.
    private func retreatRange() {
        guard let idx = allRanges.firstIndex(of: range), idx > 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            range = allRanges[idx - 1]
            if idx - 1 < windowOffset {
                windowOffset = max(idx - 1, 0)
            }
        }
    }

    private var scopeSection: some View {
        VStack(spacing: 12) {
            // Range picker with swipe-able left/right arrows
            HStack(spacing: 8) {
                // Left arrow: slides the window backward (reveals Day, hides Year)
                Button { slideWindowBackward() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(windowOffset == 0
                            ? Theme.Palette.divider : Theme.Palette.primary)
                }
                .disabled(windowOffset == 0)

                // Picker always shows exactly windowSize (3) ranges
                Picker("Range", selection: $range) {
                    ForEach(visibleRanges) { r in
                        Text(r.title).tag(r)
                    }
                }
                .pickerStyle(.segmented)

                // Right arrow: slides the window forward (reveals Year, hides Day)
                Button { slideWindowForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(windowOffset >= maxWindowOffset
                            ? Theme.Palette.divider : Theme.Palette.primary)
                }
                .disabled(windowOffset >= maxWindowOffset)
            }

            // Legacy "Test filter" chips removed. Tests were retired in
            // favor of MedChangeEvent; this UI was a vestige that scoped
            // scopedRange to the legacy test's full duration, blowing past
            // the new fixed Day/Week/Month/Year windows and causing the
            // X-axis labels to overlap. The selectedTestID state remains
            // so scopedRange's existing branch is harmless (always nil
            // now); the deeper cleanup of the field can come later.
        }
    }

    private func chip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Font.caption)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isOn ? Theme.Palette.primary : Color.white)
                .foregroundStyle(isOn ? Color.white : Theme.Palette.textPrimary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.Palette.divider, lineWidth: isOn ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private func testChipLabel(_ test: Test) -> String {
        test.displayName
    }

    // MARK: Current status

    private var currentStatusCard: some View {
        let today = todayCheckIn
        return VStack(alignment: .leading, spacing: 10) {
            Text("Current status")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            if let today {
                VStack(alignment: .leading, spacing: 10) {
                    Text(today.date.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(Theme.Font.bodyEmphasis)
                    FlowLayout(spacing: 6) {
                        ForEach(today.answers, id: \.self) { answer in
                            if let level = answer.checkInLevel {
                                statusChip(key: answer.questionKey, level: level)
                            }
                        }
                    }
                }
                .cardStyle()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No check-in yet today")
                        .font(Theme.Font.bodyEmphasis)
                    Text("Log on the Today tab to see your current snapshot here.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .cardStyle()
            }
        }
    }

    private var todayCheckIn: DailyCheckIn? {
        allCheckIns.first { calendar.isDateInToday($0.date) }
    }

    private func statusChip(key: String, level: CheckInLevel) -> some View {
        HStack(spacing: 4) {
            Text(shortLabel(for: key))
                .font(.system(size: 11, weight: .semibold))
            Text("\(level.displayName)/5")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Theme.Palette.background)
        .clipShape(Capsule())
    }


    // MARK: Overall score chart

    /// Average of all scale answers per bucket across every question.
    private var overallSeries: [ChartPoint] {
        let checkIns = checkInsInScope()
        var buckets: [Date: (sum: Double, count: Int)] = [:]
        for ci in checkIns {
            let scores = ci.answers.compactMap { $0.checkInLevel?.numericValue }.map(Double.init)
            guard !scores.isEmpty else { continue }
            let avg = scores.reduce(0, +) / Double(scores.count)
            let key = bucketKey(for: ci.date)
            let existing = buckets[key] ?? (0, 0)
            buckets[key] = (existing.sum + avg, existing.count + 1)
        }
        return buckets
            .map { ChartPoint(date: $0.key, value: $0.value.sum / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
    }

    /// % change in overall score: most recent bucket vs the one before it.
    private var overallTrendPercent: Double? {
        let points = overallSeries
        guard points.count >= 2 else { return nil }
        let current  = points.last!.value
        let previous = points[points.count - 2].value
        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    private var overallCard: some View {
        let points = overallSeries
        let showAmber = range == .day
        let missedPoints = showAmber ? points.filter { missedMedBuckets.contains($0.date) } : []
        let key = "overall"
        let selPoint = nearestChartPoint(in: points, forKey: key)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Overall score")
                    .font(Theme.Font.bodyEmphasis)
                Spacer()
                trendBadge(overallTrendPercent)
            }

            if points.isEmpty {
                emptyChartPlaceholder(text: "No entries in this window yet.")
            } else {
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Day", point.date),
                            y: .value("Score", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.Palette.primary.opacity(0.35), Theme.Palette.primary.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("Score", point.value)
                        )
                        .foregroundStyle(Theme.Palette.primary)
                        .interpolationMethod(.monotone)
                        .symbol(.circle)
                    }
                    // Selection mark — drawn before amber dots so amber stays on top
                    if let sel = selPoint {
                        RuleMark(x: .value("Day", sel.date))
                            .foregroundStyle(Theme.Palette.primary.opacity(0.25))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        PointMark(
                            x: .value("Day", sel.date),
                            y: .value("Score", sel.value)
                        )
                        .foregroundStyle(missedPoints.contains(where: { $0.date == sel.date })
                            ? Theme.Palette.attention : Theme.Palette.primary)
                        .symbolSize(200)
                        .annotation(position: .top, spacing: 4) {
                            Text(String(format: "%.1f", sel.value))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.Palette.primary)
                        }
                    }
                    // Amber dots rendered last so they always appear on top
                    ForEach(missedPoints) { point in
                        PointMark(
                            x: .value("Day", point.date),
                            y: .value("Score", point.value)
                        )
                        .foregroundStyle(Theme.Palette.attention)
                        .symbolSize(110)
                    }
                    // Vertical dashed markers at every MedChangeEvent date.
                    // Drawn last so they stay on top of the area gradient.
                    // Now that the Day chart isn't scrollable, the `.top`
                    // annotation renders cleanly across all four ranges, so
                    // the pill icon is back at the top of each marker.
                    ForEach(visibleMedChangeEvents) { event in
                        RuleMark(x: .value("Med change", markerX(for: event)))
                            .foregroundStyle(Theme.Palette.textSecondary.opacity(0.55))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                            .annotation(position: .top, alignment: .center, spacing: 2) {
                                Image(systemName: "pill.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                    }
                }
                .chartYScale(domain: 0...5)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [1, 2, 3, 4, 5]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) { Text("\(v)") }
                        }
                    }
                }
                .chartXAxis { xAxisMarks }
                // Clamp the chart's X domain to the scoped window so Swift
                // Charts doesn't auto-pad with extra days on either side —
                // that padding was producing 9 labels on the 7-day Day view
                // (Wed 3 … Thu 11) instead of the intended 7.
                .chartXScale(domain: chartXDomain)
                .frame(height: 150)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                    .onChanged { value in
                                        selectChartPoint(at: value.location,
                                                         proxy: proxy, geo: geo, key: key)
                                    }
                            )
                    }
                }

                if !missedPoints.isEmpty {
                    HStack(spacing: 5) {
                        Circle().fill(Theme.Palette.attention).frame(width: 7, height: 7)
                        Text("Amber dot = missed medication that day")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }

                medChangeMarkerChips

                if let sel = selPoint {
                    chartCallout(for: sel)
                }
            }
        }
        .cardStyle()
    }

    // MARK: Per-question charts

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your graphs")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            overallCard

            ForEach(StandardCheckInQuestion.activeCases) { q in
                if enabledStandardKeys.contains(q.rawValue) {
                    questionCard(
                        title: q.shortLabel,
                        key: q.rawValue,
                        onRemove: { enabledStandardKeys.remove(q.rawValue) }
                    )
                }
            }

            ForEach(customQuestions) { cq in
                if enabledCustomKeys.contains(cq.storageKey) {
                    questionCard(
                        title: cq.prompt,
                        key: cq.storageKey,
                        onRemove: { enabledCustomKeys.remove(cq.storageKey) }
                    )
                }
            }
        }
    }

    private func questionCard(title: String, key: String, onRemove: @escaping () -> Void) -> some View {
        let points = bucketedSeries(for: key)
        let selPoint = nearestChartPoint(in: points, forKey: key)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(Theme.Font.bodyEmphasis)
                Spacer()
                trendBadge(trendPercent(for: key))
                Menu {
                    Button("Remove graph", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }

            if points.isEmpty {
                emptyChartPlaceholder(text: "No entries in this window yet.")
            } else {
                let showAmber = range == .day
                let missedPoints = showAmber ? points.filter { missedMedBuckets.contains($0.date) } : []
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Day", point.date),
                            y: .value("Level", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.Palette.primary.opacity(0.35), Theme.Palette.primary.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("Level", point.value)
                        )
                        .foregroundStyle(Theme.Palette.primary)
                        .interpolationMethod(.monotone)
                        .symbol(.circle)
                    }
                    // Selection mark — drawn before amber dots so amber stays on top
                    if let sel = selPoint {
                        RuleMark(x: .value("Day", sel.date))
                            .foregroundStyle(Theme.Palette.primary.opacity(0.25))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        PointMark(
                            x: .value("Day", sel.date),
                            y: .value("Level", sel.value)
                        )
                        .foregroundStyle(missedPoints.contains(where: { $0.date == sel.date })
                            ? Theme.Palette.attention : Theme.Palette.primary)
                        .symbolSize(200)
                        .annotation(position: .top, spacing: 4) {
                            Text(String(format: "%.1f", sel.value))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.Palette.primary)
                        }
                    }
                    // Amber dots rendered last so they always appear on top
                    ForEach(missedPoints) { point in
                        PointMark(
                            x: .value("Day", point.date),
                            y: .value("Level", point.value)
                        )
                        .foregroundStyle(Theme.Palette.attention)
                        .symbolSize(110)
                    }
                    // Vertical dashed markers at every MedChangeEvent date.
                    ForEach(visibleMedChangeEvents) { event in
                        RuleMark(x: .value("Med change", markerX(for: event)))
                            .foregroundStyle(Theme.Palette.textSecondary.opacity(0.55))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                            .annotation(position: .top, alignment: .center, spacing: 2) {
                                Image(systemName: "pill.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                    }
                }
                .chartYScale(domain: 0...5)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [1, 2, 3, 4, 5]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) { Text("\(v)") }
                        }
                    }
                }
                .chartXAxis { xAxisMarks }
                // Clamp the chart's X domain to the scoped window so Swift
                // Charts doesn't auto-pad with extra days on either side —
                // that padding was producing 9 labels on the 7-day Day view
                // (Wed 3 … Thu 11) instead of the intended 7.
                .chartXScale(domain: chartXDomain)
                .frame(height: 150)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                    .onChanged { value in
                                        selectChartPoint(at: value.location,
                                                         proxy: proxy, geo: geo, key: key)
                                    }
                            )
                    }
                }

                if !missedPoints.isEmpty {
                    HStack(spacing: 5) {
                        Circle().fill(Theme.Palette.attention).frame(width: 7, height: 7)
                        Text("Amber dot = missed medication that day")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }

                medChangeMarkerChips

                if let sel = selPoint {
                    chartCallout(for: sel)
                }
            }
        }
        .cardStyle()
    }

    private func emptyChartPlaceholder(text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Spacer()
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
    }

    private var addGraphButton: some View {
        Button {
            showingAddGraph = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add a graph")
                Spacer()
            }
            .font(Theme.Font.bodyEmphasis)
            .foregroundStyle(Theme.Palette.primary)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        Theme.Palette.primary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// Bucket keys where at least one scheduled med was skipped.
    /// Keyed by bucketKey so it works correctly for day/week/month/year views.
    private var missedMedBuckets: Set<Date> {
        Set(adherenceLogs
            .filter { !$0.skippedMedIDs.isEmpty }
            .map { bucketKey(for: $0.date) }
        )
    }

    // MARK: Data bucketing

    struct ChartSeries: Identifiable {
        let id = UUID()
        let label: String
        let points: [ChartPoint]
    }

    struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    /// Closed date range used for `.chartXScale(domain:)` so each chart's
    /// X-axis is exactly the scoped window — no auto-padding before the
    /// first bucket or after the last bucket. Both endpoints are aligned
    /// to bucket boundaries so the axis labels land on real ticks.
    private var chartXDomain: ClosedRange<Date> {
        let (start, end) = scopedRange
        let alignedStart = calendar.dateInterval(of: bucketUnit, for: start)?.start ?? start
        let alignedEnd   = calendar.dateInterval(of: bucketUnit, for: end)?.start ?? end
        // If start == end (rare), nudge end forward by one bucket so the
        // domain is non-empty; otherwise SwiftUI's Chart can't lay out.
        guard alignedStart < alignedEnd else {
            let nudged = calendar.date(byAdding: bucketUnit, value: 1, to: alignedStart) ?? alignedStart
            return alignedStart ... nudged
        }
        // Live (non-test) scopes get trailing headroom so today's point sits
        // about two-thirds of the way across instead of pinned to the right
        // edge. Half the visible span of empty future keeps the latest point
        // readable (annotation has room) and shows where the trend is headed.
        // Historical test windows stay exact — their end isn't "now".
        if selectedTestID == nil {
            let span = alignedEnd.timeIntervalSince(alignedStart)
            let padded = alignedEnd.addingTimeInterval(span / 2)
            return alignedStart ... padded
        }
        return alignedStart ... alignedEnd
    }

    private var bucketUnit: Calendar.Component {
        switch range {
        case .day:   return .day
        case .week:  return .weekOfYear
        case .month: return .month
        // Year now buckets by month so we get 12 monthly dots across a year
        // (matches the agreed UX), not 5 yearly dots across 5 years.
        case .year:  return .month
        }
    }

    private var scopedRange: (start: Date, end: Date) {
        if let testID = selectedTestID, let test = tests.first(where: { $0.id == testID }) {
            let end = test.actualEndDate ?? test.plannedEndDate ?? Date()
            return (calendar.startOfDay(for: test.startDate), end)
        }
        let end   = Date()
        let today = calendar.startOfDay(for: end)
        let start: Date
        // Fixed windows per agreed UX (no chart scrolling needed):
        //   Day   = last 7 days        (1 week)
        //   Week  = last 4 weeks       (1 month)
        //   Month = last 3 months      (1 quarter)
        //   Year  = last 12 months     (1 year)
        // Anchored at "today" — windows roll forward as time passes.
        switch range {
        case .day:
            start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .week:
            let currentWeekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            ) ?? today
            start = calendar.date(byAdding: .weekOfYear, value: -3, to: currentWeekStart) ?? today
        case .month:
            let currentMonthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: today)
            ) ?? today
            start = calendar.date(byAdding: .month, value: -2, to: currentMonthStart) ?? today
        case .year:
            let currentMonthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: today)
            ) ?? today
            start = calendar.date(byAdding: .month, value: -11, to: currentMonthStart) ?? today
        }
        return (start, end)
    }

    private func checkInsInScope() -> [DailyCheckIn] {
        let (start, _) = scopedRange
        let now = Date()
        return allCheckIns.filter {
            Self.isCheckInInScope($0.date, start: start, now: now, calendar: calendar)
        }
    }

    /// Whether a check-in counts toward charts/trends for the current scope:
    /// at/after `start`, and strictly before the start of tomorrow. The upper
    /// bound excludes future-dated check-ins — the app lets users log ahead in
    /// the Today strip, but a future point the chart domain clips off must not
    /// still move the trend % (M5). (Extracted as a static for testability.)
    static func isCheckInInScope(_ date: Date, start: Date, now: Date, calendar: Calendar) -> Bool {
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now
        return date >= start && date < startOfTomorrow
    }

    /// % change for one question key: most recent bucket vs the one before it.
    private func trendPercent(for questionKey: String) -> Double? {
        let points = bucketedSeries(for: questionKey)
        guard points.count >= 2 else { return nil }
        let current  = points.last!.value
        let previous = points[points.count - 2].value
        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    /// Compact trend badge — "↑ 12%" green or "↓ 5%" coral.
    @ViewBuilder
    private func trendBadge(_ percent: Double?) -> some View {
        if let pct = percent {
            let isUp = pct >= 0
            let label = "\(isUp ? "↑" : "↓") \(String(format: "%.1f", abs(pct)))%"
            let color: Color = isUp ? Theme.Palette.success : Theme.Palette.negative
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func bucketedSeries(for questionKey: String) -> [ChartPoint] {
        let checkIns = checkInsInScope()
        var buckets: [Date: (sum: Double, count: Int)] = [:]
        for ci in checkIns {
            guard let level = ci.answers.first(where: { $0.questionKey == questionKey })?.checkInLevel else { continue }
            let bucketDate = bucketKey(for: ci.date)
            let existing = buckets[bucketDate] ?? (0, 0)
            buckets[bucketDate] = (existing.sum + Double(level.numericValue), existing.count + 1)
        }
        return buckets
            .map { ChartPoint(date: $0.key, value: $0.value.sum / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
    }

    private func bucketKey(for date: Date) -> Date {
        Self.bucketKey(for: date, range: range, calendar: calendar)
    }

    /// Pure bucketing used by the score series AND the medication-change
    /// markers (extracted for testability — see H3 bucket-boundary tests).
    /// A date is collapsed to the start of its day/week/month bucket so a
    /// marker logged at any time within a bucket aligns with that bucket's
    /// data point and stays inside the clamped chart domain.
    static func bucketKey(for date: Date, range: InsightsRange, calendar: Calendar) -> Date {
        switch range {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        case .year:
            // Year view shows 12 monthly buckets, so bucket by month (not
            // year) — matches bucketUnit (.month) and the monthly X domain.
            let comps = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        }
    }

    @AxisContentBuilder
    private var xAxisMarks: some AxisContent {
        switch range {
        case .day:
            // ~10 daily ticks once trailing headroom is added → label every
            // other day ("Wed 28") so labels never collide.
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated).day())
            }
        case .week:
            // 4 weekly dots → label each week's start in "M/d" form.
            AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
            }
        case .month:
            // 3 monthly dots → label each as abbreviated month name.
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        case .year:
            // 12 monthly dots — label every other month to avoid clutter.
            AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.narrow))
            }
        }
    }

    private func shortLabel(for key: String) -> String {
        if let std = StandardCheckInQuestion(rawValue: key) {
            return std.shortLabel
        }
        if let custom = customQuestions.first(where: { $0.storageKey == key }) {
            return custom.prompt
        }
        return "Custom"
    }

    // MARK: - Chart interaction helpers

    /// Converts a touch location (from a chartOverlay GeometryReader) into the nearest
    /// data date and updates the shared selection state. Works for both taps and drags.
    private func selectChartPoint(at location: CGPoint,
                                   proxy: ChartProxy,
                                   geo: GeometryProxy,
                                   key: String) {
        let plotFrame = geo[proxy.plotAreaFrame]
        let relativeX = location.x - plotFrame.origin.x
        guard relativeX >= 0, relativeX <= plotFrame.width else { return }
        let date: Date? = proxy.value(atX: relativeX)
        if let date {
            chartSelectedKey = key
            chartSelectedDate = date
        }
    }

    private func chartSelectionBinding(for key: String) -> Binding<Date?> {
        Binding(
            get: { chartSelectedKey == key ? chartSelectedDate : nil },
            set: { newDate in
                if newDate != nil {
                    chartSelectedKey = key
                    chartSelectedDate = newDate
                } else if chartSelectedKey == key {
                    chartSelectedKey = nil
                    chartSelectedDate = nil
                }
            }
        )
    }

    private func nearestChartPoint(in points: [ChartPoint], forKey key: String) -> ChartPoint? {
        guard chartSelectedKey == key, let selDate = chartSelectedDate else { return nil }
        return points.min(by: {
            abs($0.date.timeIntervalSince(selDate)) < abs($1.date.timeIntervalSince(selDate))
        })
    }

    private func chartCallout(for point: ChartPoint) -> some View {
        let checkIn = allCheckIns.first {
            calendar.isDate($0.date, inSameDayAs: point.date)
        }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bucketLabel(for: point.date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(String(format: "%.1f / 5", point.value))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            if let checkIn {
                Button {
                    viewingCheckInFromChart = checkIn
                } label: {
                    HStack(spacing: 4) {
                        Text("View check-in")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.Palette.primary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func bucketLabel(for date: Date) -> String {
        switch range {
        case .day:
            return date.formatted(.dateTime.weekday(.wide).month().day())
        case .week:
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: date) ?? date
            return "\(date.formatted(.dateTime.month(.abbreviated).day())) – \(weekEnd.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        case .year:
            return date.formatted(.dateTime.year())
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct AddGraphSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var standardEnabled: Set<String>
    @Binding var customEnabled: Set<String>
    let customQuestions: [CustomCheckInQuestion]
    let tests: [Test]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionHeader("Standard questions")
                    ForEach(StandardCheckInQuestion.activeCases) { q in
                        toggleRow(
                            title: q.shortLabel,
                            subtitle: q.prompt,
                            isOn: Binding(
                                get: { standardEnabled.contains(q.rawValue) },
                                set: { on in
                                    if on { standardEnabled.insert(q.rawValue) }
                                    else { standardEnabled.remove(q.rawValue) }
                                }
                            )
                        )
                    }

                    if !customQuestions.isEmpty {
                        sectionHeader("Your questions")
                        ForEach(customQuestions) { cq in
                            toggleRow(
                                title: cq.prompt,
                                subtitle: scopeSubtitle(for: cq),
                                isOn: Binding(
                                    get: { customEnabled.contains(cq.storageKey) },
                                    set: { on in
                                        if on { customEnabled.insert(cq.storageKey) }
                                        else { customEnabled.remove(cq.storageKey) }
                                    }
                                )
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.Palette.background)
            .navigationTitle("Add a graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func scopeSubtitle(for question: CustomCheckInQuestion) -> String? {
        guard let testID = question.testID else { return nil }
        let test = tests.first(where: { $0.id == testID })
        return test.map { "For test: \($0.displayName)" } ?? "Test no longer exists"
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.textSecondary)
            .padding(.leading, 4)
    }

    private func toggleRow(title: String, subtitle: String?, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Font.bodyEmphasis)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
        .tint(Theme.Palette.primary)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}
