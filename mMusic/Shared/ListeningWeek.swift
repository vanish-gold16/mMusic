import Foundation
import SwiftData

/// Неделя прослушиваний по кусочкам суток: сколько секунд звучала музыка
/// в каждые два часа последних семи дней. Из неё на главной рисуется
/// неделя одной звуковой дорожкой — как лента плейлиста, только вместо
/// треков дни.
///
/// Считается по истории `PlayEvent`, а не по трекам: `lastPlayedAt` знает
/// только последний раз, а время — только история.
struct ListeningWeek: Equatable {

    /// Сколько кусочков в сутках. Два часа на кусочек: по часу столбики
    /// выходили тоньше волоса, а по четыре — утро сливалось с ночью.
    static let slotsPerDay = 12

    struct Day: Equatable {
        /// Начало дня.
        let date: Date
        /// Секунды в каждом кусочке, `slotsPerDay` штук.
        let slots: [TimeInterval]

        var total: TimeInterval { slots.reduce(0, +) }
    }

    /// Семь дней по порядку, последний — сегодня.
    let days: [Day]

    var today: TimeInterval { days.last?.total ?? 0 }
    var total: TimeInterval { days.reduce(0) { $0 + $1.total } }

    /// Самый громкий кусочек недели — по нему мерится высота остальных.
    var loudestSlot: TimeInterval {
        days.flatMap(\.slots).max() ?? 0
    }

    static let empty = ListeningWeek(days: [])

    /// Раскладывает прослушивания по кусочкам. Событие целиком ложится туда,
    /// где оно началось: история не знает, как секунды шли по часам, и
    /// песня, начатая без пяти полночь, остаётся вчерашней.
    static func make(
        from plays: [(playedAt: Date, seconds: TimeInterval)],
        endingOn date: Date = .now,
        calendar: Calendar = .current
    ) -> ListeningWeek {
        let today = calendar.startOfDay(for: date)
        let starts = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        guard let first = starts.first else { return .empty }

        var slots = Array(repeating: Array(repeating: 0.0, count: slotsPerDay), count: starts.count)
        let hoursPerSlot = 24 / slotsPerDay

        for play in plays where play.playedAt >= first && play.seconds > 0 {
            let day = calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: play.playedAt)).day ?? -1
            guard slots.indices.contains(day) else { continue }

            let slot = min(calendar.component(.hour, from: play.playedAt) / hoursPerSlot, slotsPerDay - 1)
            slots[day][slot] += play.seconds
        }

        return ListeningWeek(days: zip(starts, slots).map { Day(date: $0, slots: $1) })
    }

    /// Та же неделя, но история берётся из базы — одним запросом и только
    /// за эти семь дней: вся история за годы для этого не нужна.
    static func make(in context: ModelContext, endingOn date: Date = .now, calendar: Calendar = .current) -> ListeningWeek {
        let today = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return .empty }

        let descriptor = FetchDescriptor<PlayEvent>(predicate: #Predicate { $0.playedAt >= start })
        let events = (try? context.fetch(descriptor)) ?? []

        return make(from: events.map { ($0.playedAt, $0.seconds) }, endingOn: date, calendar: calendar)
    }
}

extension TimeInterval {

    /// «47 MIN» или «6 H 12 MIN» — часы появляются, только когда они есть.
    /// Заглавными: строка стоит в паспорте, а он везде набран капителью.
    var listeningLabel: String {
        let minutes = Int((self / 60).rounded())
        guard minutes >= 60 else { return "\(minutes) MIN" }

        return minutes % 60 == 0 ? "\(minutes / 60) H" : "\(minutes / 60) H \(minutes % 60) MIN"
    }
}
