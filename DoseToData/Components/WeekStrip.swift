import SwiftUI

struct WeekStrip: View {
    let completedDates: Set<Date>
    let today: Date

    private var weekDays: [WeekDay] {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2 // Monday

        guard let interval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return []
        }
        let start = interval.start
        return (0..<7).compactMap { offset -> WeekDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let normalized = calendar.startOfDay(for: date)
            return WeekDay(
                date: normalized,
                weekdayShort: date.formatted(.dateTime.weekday(.abbreviated)),
                dayNumber: calendar.component(.day, from: date),
                isToday: calendar.isDate(date, inSameDayAs: today),
                isCompleted: completedDates.contains(normalized),
                isFuture: date > today && !calendar.isDate(date, inSameDayAs: today)
            )
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDays) { day in
                DayCell(day: day)
            }
        }
    }
}

private struct WeekDay: Identifiable {
    let date: Date
    let weekdayShort: String
    let dayNumber: Int
    let isToday: Bool
    let isCompleted: Bool
    let isFuture: Bool

    var id: Date { date }
}

private struct DayCell: View {
    let day: WeekDay

    private var background: Color {
        if day.isCompleted {
            return Theme.Palette.success
        }
        if day.isToday {
            return Theme.Palette.heroAccent
        }
        return Color.white
    }

    private var foreground: Color {
        if day.isCompleted {
            return .white
        }
        if day.isFuture {
            return Theme.Palette.textSecondary.opacity(0.6)
        }
        return Theme.Palette.textPrimary
    }

    private var strokeColor: Color {
        if day.isToday && !day.isCompleted {
            return Theme.Palette.primary
        }
        return Color.clear
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(day.weekdayShort.prefix(3).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(day.isCompleted ? .white.opacity(0.9) : Theme.Palette.textSecondary)
            ZStack {
                Circle()
                    .fill(background)
                    .overlay(Circle().stroke(strokeColor, lineWidth: 2))
                    .frame(width: 36, height: 36)
                if day.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(day.dayNumber)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(foreground)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
