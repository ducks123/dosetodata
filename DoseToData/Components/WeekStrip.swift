import SwiftUI

// MARK: - Day state

/// The visual state for a single day cell in the week strip.
enum WeekDayState {
    /// Nothing logged — empty circle.
    case empty
    /// Meds confirmed via notification quick-action, check-in not yet done → green ring.
    case medsTaken
    /// Check-in complete + all meds taken (or no meds scheduled) → filled green circle.
    case complete
    /// Check-in complete + at least one med skipped → amber ring with checkmark.
    case medsMissed
}

// MARK: - DateScrollStrip (smooth continuous horizontal scroll)

/// A horizontal scrollable strip of date cells — replaces the chunky weekly jump.
/// Scrolls from `earliestDate` (or 180 days back) through 365 days in the future.
struct DateScrollStrip: View {
    let dayStates: [Date: WeekDayState]
    let today: Date
    let selectedDate: Date
    /// The earliest date with actual data. The strip will start here (or 180 days
    /// back if nil), so there's no artificial cutoff.
    var earliestDate: Date? = nil
    let onSelectDate: (Date) -> Void

    private let calendar = Calendar.current

    private var dates: [Date] {
        let todayStart = calendar.startOfDay(for: today)
        // Always show at least 180 days of history. If the user has older
        // check-ins than that, extend further back to include them — but
        // never shrink below 180. Without this floor, the strip collapses
        // to start at the user's earliest check-in (often today on a fresh
        // install), making it impossible to scroll back and log past days.
        let daysBack: Int
        if let earliest = earliestDate {
            let computed = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: earliest),
                to: todayStart
            ).day ?? 180
            daysBack = max(computed, 180)
        } else {
            daysBack = 180
        }
        return ((-daysBack)...365).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: todayStart)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(dates, id: \.self) { date in
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isToday   = calendar.isDate(date, inSameDayAs: today)
                        let state     = dayStates[date] ?? .empty

                        ScrollDayCell(date: date, isSelected: isSelected,
                                      isToday: isToday, state: state)
                            .id(date)
                            .onTapGesture { onSelectDate(date) }
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(calendar.startOfDay(for: selectedDate), anchor: .center)
                }
            }
            .onChange(of: selectedDate) { _, newDate in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(calendar.startOfDay(for: newDate), anchor: .center)
                }
            }
        }
    }
}

// MARK: - ScrollDayCell

private struct ScrollDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let state: WeekDayState

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(isToday ? Theme.Palette.primary : Color.clear)
                .frame(width: 6, height: 6)

            Text(String(date.formatted(.dateTime.weekday(.abbreviated)).prefix(3)))
                .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary)

            ZStack {
                stateBackground
                if isSelected {
                    Circle()
                        .stroke(Theme.Palette.primary, lineWidth: 2.5)
                        .frame(width: 34, height: 34)
                }
                stateContent
            }
            .padding(.bottom, 2)
        }
        .frame(width: 42)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder private var stateBackground: some View {
        switch state {
        case .empty:
            Circle().fill(Color.white).frame(width: 34, height: 34)
        case .medsTaken:
            Circle().fill(Color.white)
                .overlay(Circle().stroke(Theme.Palette.success, lineWidth: 2.5))
                .frame(width: 34, height: 34)
        case .complete:
            Circle().fill(Theme.Palette.success).frame(width: 34, height: 34)
        case .medsMissed:
            Circle().fill(Color.white)
                .overlay(Circle().stroke(Theme.Palette.attention, lineWidth: 2.5))
                .frame(width: 34, height: 34)
        }
    }

    @ViewBuilder private var stateContent: some View {
        let dayNum = calendar.component(.day, from: date)
        switch state {
        case .empty:
            Text("\(dayNum)")
                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
        case .medsTaken:
            Text("\(dayNum)")
                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(Theme.Palette.success)
        case .complete:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        case .medsMissed:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.Palette.attention)
        }
    }
}

// MARK: - DateStripLegend
//
// A small, unobtrusive key explaining what the four cell styles in the
// date strip mean. Designed to sit directly below the strip in TodayView.

struct DateStripLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            legendItem(swatch: completeSwatch, label: "Meds taken and logged")
            legendItem(swatch: medsMissedSwatch, label: "Meds missed")
            legendItem(swatch: emptySwatch, label: "Not logged")
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.Palette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 2)
    }

    private func legendItem<S: View>(swatch: S, label: String) -> some View {
        HStack(spacing: 5) {
            swatch
            Text(label)
        }
    }

    private var completeSwatch: some View {
        ZStack {
            Circle().fill(Theme.Palette.success).frame(width: 14, height: 14)
            Image(systemName: "checkmark")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var medsMissedSwatch: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Theme.Palette.attention, lineWidth: 2))
                .frame(width: 14, height: 14)
            Image(systemName: "checkmark")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(Theme.Palette.attention)
        }
    }

    private var emptySwatch: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Theme.Palette.divider, lineWidth: 1))
            .frame(width: 14, height: 14)
    }
}

// MARK: - WeekStrip (kept for any legacy usage)

struct WeekStrip: View {
    /// State keyed by normalized date (start of day). Dates absent from the map are `.empty`.
    let dayStates: [Date: WeekDayState]
    /// The real today — used for the "today" dot indicator.
    let today: Date
    /// Which day is currently selected — shown with a blue ring.
    let selectedDate: Date
    /// Which week to display. Pass a date in any day of the desired week.
    var referenceDate: Date = Date()
    var onSelectDate: ((Date) -> Void)? = nil

    private var weekDays: [WeekDay] {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2 // Monday first

        guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return []
        }
        let start = interval.start
        let todayStart = calendar.startOfDay(for: today)
        let selectedStart = calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { offset -> WeekDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let normalized = calendar.startOfDay(for: date)
            let isFuture = normalized > todayStart
            let state: WeekDayState = isFuture ? .empty : (dayStates[normalized] ?? .empty)
            return WeekDay(
                date: normalized,
                weekdayShort: date.formatted(.dateTime.weekday(.abbreviated)),
                dayNumber: calendar.component(.day, from: date),
                isToday: calendar.isDate(date, inSameDayAs: today),
                isFuture: isFuture,
                isSelected: normalized == selectedStart,
                state: state
            )
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDays) { day in
                if let onSelectDate {
                    Button {
                        onSelectDate(day.date)
                    } label: {
                        DayCell(day: day)
                    }
                    .buttonStyle(.plain)
                } else {
                    DayCell(day: day)
                }
            }
        }
    }
}

// MARK: - WeekDay model

private struct WeekDay: Identifiable {
    let date: Date
    let weekdayShort: String
    let dayNumber: Int
    let isToday: Bool
    let isFuture: Bool
    let isSelected: Bool
    let state: WeekDayState

    var id: Date { date }
}

// MARK: - DayCell

private struct DayCell: View {
    let day: WeekDay

    var body: some View {
        VStack(spacing: 2) {
            // Small dot above the label — visible only for today
            Circle()
                .fill(day.isToday ? Theme.Palette.primary : Color.clear)
                .frame(width: 6, height: 6)

            Text(day.weekdayShort.prefix(3).uppercased())
                .font(.system(size: 11, weight: day.isSelected ? .bold : .semibold))
                .foregroundStyle(day.isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary)
                .padding(.bottom, 2)

            ZStack {
                circle
                // Blue selection ring — sits on top of the state circle
                if day.isSelected {
                    Circle()
                        .stroke(Theme.Palette.primary, lineWidth: 2.5)
                        .frame(width: 36, height: 36)
                }
                icon
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Circle background / ring

    @ViewBuilder
    private var circle: some View {
        switch day.state {
        case .empty:
            Circle()
                .fill(Color.white)
                .frame(width: 36, height: 36)

        case .medsTaken:
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Theme.Palette.success, lineWidth: 2.5))
                .frame(width: 36, height: 36)

        case .complete:
            Circle()
                .fill(Theme.Palette.success)
                .frame(width: 36, height: 36)

        case .medsMissed:
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Theme.Palette.attention, lineWidth: 2.5))
                .frame(width: 36, height: 36)
        }
    }

    // MARK: Inner content

    @ViewBuilder
    private var icon: some View {
        switch day.state {
        case .empty:
            Text("\(day.dayNumber)")
                .font(.system(size: 15, weight: day.isSelected ? .bold : .semibold))
                .foregroundStyle(day.isFuture ? Theme.Palette.textSecondary.opacity(0.4) : Theme.Palette.textPrimary)

        case .medsTaken:
            Text("\(day.dayNumber)")
                .font(.system(size: 15, weight: day.isSelected ? .bold : .semibold))
                .foregroundStyle(Theme.Palette.success)

        case .complete:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)

        case .medsMissed:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.Palette.attention)
        }
    }
}
