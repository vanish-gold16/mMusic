import Foundation
import SwiftData

/// Годовщина трека: сколько лет назад он появился в библиотеке и что за это время
/// с ним произошло.
///
/// Считается по `Track.addedAt`, а прослушивания — по истории `PlayEvent`, потому
/// что `playCount` знает только число запусков, но не время.
struct TrackBirthday: Identifiable {

    let track: Track
    /// Сколько лет исполняется — всегда 1 и больше.
    let years: Int
    let plays: Int
    let seconds: TimeInterval

    var id: PersistentIdentifier { track.persistentModelID }

    var title: String {
        years == 1 ? "1 year with this track" : "\(years) years with this track"
    }

    /// «3 h 12 min» или «47 min» — часы появляются, только когда они есть.
    var listeningTime: String {
        let minutes = Int(seconds / 60)
        guard minutes >= 60 else { return "\(minutes) min" }

        return "\(minutes / 60) h \(minutes % 60) min"
    }

    var summary: String {
        let played = plays == 1 ? "1 play" : "\(plays) plays"
        return seconds > 0 ? "\(played) • \(listeningTime)" : played
    }

    /// Треки, у которых годовщина сегодня. Самые заслуженные — первыми.
    static func today(
        in tracks: [Track],
        listened: [String: TimeInterval],
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> [TrackBirthday] {
        let today = calendar.startOfDay(for: date)

        let celebrating = tracks.compactMap { track -> (Track, Int)? in
            guard let anniversary = anniversary(of: track.addedAt, in: calendar.component(.year, from: date), calendar: calendar),
                  calendar.startOfDay(for: anniversary) == today
            else { return nil }

            // Возраст считается по номерам годов, а не разницей дат: трек, добавленный
            // вечером, празднует с утра — иначе «без пары часов год» округляется в ноль.
            let years = calendar.component(.year, from: date) - calendar.component(.year, from: track.addedAt)
            guard years >= 1 else { return nil }

            return (track, years)
        }

        return celebrating
            .map { track, years in
                TrackBirthday(
                    track: track,
                    years: years,
                    plays: track.playCount,
                    seconds: listened[track.filename] ?? 0
                )
            }
            .sorted { $0.plays > $1.plays }
    }

    /// Ближайшие годовщины на год вперёд — по ним расставляются уведомления.
    /// Возвращается плоский слепок: уведомления переживают удаление трека,
    /// а держать ссылку на модель ради этого незачем.
    static func upcoming(
        in tracks: [Track],
        listened: [String: TimeInterval],
        from date: Date = .now,
        calendar: Calendar = .current,
        limit: Int
    ) -> [Upcoming] {
        let today = calendar.startOfDay(for: date)

        return tracks
            .compactMap { track -> Upcoming? in
                guard let next = nextAnniversary(of: track.addedAt, after: today, calendar: calendar),
                      next.years >= 1
                else { return nil }

                return Upcoming(
                    name: track.name,
                    filename: track.filename,
                    date: next.date,
                    years: next.years,
                    plays: track.playCount,
                    seconds: listened[track.filename] ?? 0
                )
            }
            .sorted { $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
    }

    /// Годовщина без ссылки на модель — всё, что нужно тексту уведомления.
    struct Upcoming {
        let name: String
        let filename: String
        let date: Date
        let years: Int
        let plays: Int
        let seconds: TimeInterval

        var body: String {
            let played = plays == 1 ? "1 play" : "\(plays) plays"
            let minutes = Int(seconds / 60)
            let time = minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
            let age = years == 1 ? "1 year in your library" : "\(years) years in your library"

            return seconds > 0 ? "\(age) • \(played) • \(time)" : "\(age) • \(played)"
        }
    }

    /// Сколько секунд слушали каждый трек — одним проходом по всей истории.
    /// Отдельный запрос на трек обошёлся бы в сотни выборок на запуске.
    /// История хранит имя файла, а не ссылку на модель, поэтому ключ — оно.
    static func listened(in context: ModelContext) -> [String: TimeInterval] {
        let events = (try? context.fetch(FetchDescriptor<PlayEvent>())) ?? []

        return events.reduce(into: [:]) { totals, event in
            totals[event.trackFilename, default: 0] += event.seconds
        }
    }

    /// Тот же день и месяц, но в заданном году. 29 февраля календарь сам переносит
    /// на 1 марта — в невисокосный год трек всё равно получит свой праздник.
    private static func anniversary(of addedAt: Date, in year: Int, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.month, .day], from: addedAt)
        components.year = year
        components.hour = 0

        return calendar.date(from: components)
    }

    private static func nextAnniversary(
        of addedAt: Date,
        after day: Date,
        calendar: Calendar
    ) -> (date: Date, years: Int)? {
        let year = calendar.component(.year, from: day)

        for candidateYear in [year, year + 1] {
            guard let date = anniversary(of: addedAt, in: candidateYear, calendar: calendar),
                  calendar.startOfDay(for: date) >= day
            else { continue }

            return (date, candidateYear - calendar.component(.year, from: addedAt))
        }

        return nil
    }
}
