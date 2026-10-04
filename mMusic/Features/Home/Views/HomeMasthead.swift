import SwiftUI

/// Шапка главной: день недели крупным сжатым шрифтом, паспорт дня и неделя
/// одной звуковой дорожкой. Вместо «Good evening» над лентой рекомендаций —
/// дата, как на корешке дневника, и то, как эта неделя звучала.
struct HomeMasthead: View {

    let week: ListeningWeek
    /// Сейчас. Передаётся снаружи: главная обновляет его, когда приложение
    /// возвращается из фона, — иначе после полуночи шапка жила бы вчерашним днём.
    let now: Date
    let accent: Color

    private var weekday: String {
        now.formatted(.dateTime.weekday(.wide).locale(.interface))
    }

    /// «OCT 4  ·  47 MIN TODAY  ·  6 H THIS WEEK». Пустые части не пишутся:
    /// «0 MIN TODAY» звучит упрёком, а не сводкой.
    private var passport: String {
        var parts = [now.formatted(.dateTime.month(.abbreviated).day().locale(.interface))]

        if week.today >= 60 {
            parts.append("\(week.today.listeningLabel) today")
        }
        if week.total >= 60, week.total - week.today >= 60 {
            parts.append("\(week.total.listeningLabel) this week")
        }
        if week.total < 60 {
            parts.append("quiet week")
        }

        return parts.joined(separator: "  ·  ").uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(weekday)
                .font(.system(size: 44, weight: .heavy).width(.compressed))

            Text(passport)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)

            WeekTape(week: week, now: now, accent: accent)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

/// Неделя звуковой дорожкой: семь дней подряд, в каждом столбики по два часа,
/// высота — сколько в эти часы звучала музыка. Сегодня горит акцентом,
/// а ещё не наступившие часы сегодняшнего дня едва видны — день не кончился.
///
/// Тот же рисунок, что у ленты плейлиста (`PlaylistTape`): там столбики —
/// громкость песен, здесь — громкость твоей недели.
struct WeekTape: View {

    let week: ListeningWeek
    let now: Date
    let accent: Color

    /// Зазор между днями — шире, чем между столбиками, чтобы дни читались.
    private let dayGap: CGFloat = 6
    private let height: CGFloat = 44

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .frame(height: height)

            HStack(spacing: dayGap) {
                ForEach(Array(week.days.enumerated()), id: \.offset) { index, day in
                    Text(day.date.formatted(.dateTime.weekday(.narrow).locale(.interface)))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(index == week.days.count - 1 ? AnyShapeStyle(accent) : AnyShapeStyle(.tertiary))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("This week")
        .accessibilityValue(Text(week.total >= 60 ? week.total.listeningLabel.lowercased() : "nothing played"))
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let days = week.days
        guard !days.isEmpty else { return }

        let dayWidth = (size.width - dayGap * CGFloat(days.count - 1)) / CGFloat(days.count)
        let slots = ListeningWeek.slotsPerDay
        let step = dayWidth / CGFloat(slots)
        let barWidth = max(1.5, step * 0.62)
        let loudest = week.loudestSlot

        // Какой кусочек сегодняшнего дня идёт сейчас: всё правее — ещё будущее.
        let hour = Calendar.current.component(.hour, from: now)
        let currentSlot = hour / (24 / slots)

        for (dayIndex, day) in days.enumerated() {
            let isToday = dayIndex == days.count - 1
            let left = CGFloat(dayIndex) * (dayWidth + dayGap)

            for (slot, seconds) in day.slots.enumerated() {
                let isFuture = isToday && slot > currentSlot

                // Корень, как у волны трека: иначе один длинный вечер
                // придавил бы к полу все остальные часы недели.
                let level = loudest > 0 ? (seconds / loudest).squareRoot() : 0
                let barHeight = max(2, CGFloat(level) * size.height)

                let rect = CGRect(
                    x: left + CGFloat(slot) * step + (step - barWidth) / 2,
                    y: (size.height - barHeight) / 2,
                    width: barWidth,
                    height: barHeight
                )

                let color: Color
                if isFuture {
                    color = .primary.opacity(0.07)
                } else if isToday {
                    color = seconds > 0 ? accent : accent.opacity(0.35)
                } else {
                    color = .primary.opacity(seconds > 0 ? 0.3 : 0.14)
                }

                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color))
            }
        }
    }
}
