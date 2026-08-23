import Foundation
import SwiftData

/// Годовщина трека: сколько лет назад он вышел и что за это время с ним произошло.
///
/// Считается от даты релиза альбома. Её знают не все треки — у одиночного импорта
/// альбома может не быть вовсе, — поэтому для остальных годовщина отсчитывается
/// от дня, когда трек попал в библиотеку, и называется по-другому.
///
/// Прослушивания берутся из истории `PlayEvent`: `playCount` знает число запусков,
/// но не время.
struct TrackBirthday: Identifiable {

    /// От чего считается годовщина — от этого зависит и подпись.
    enum Kind {
        /// Дата выхода альбома.
        case release
        /// День добавления в библиотеку: даты релиза у трека нет.
        case library
    }

    let track: Track
    let kind: Kind
    /// Дата, от которой идёт отсчёт: релиз или добавление.
    let origin: Date
    /// Сколько лет исполняется — всегда 1 и больше.
    let years: Int
    let plays: Int
    let seconds: TimeInterval

    var id: PersistentIdentifier { track.persistentModelID }

    var title: String {
        switch kind {
        case .release:
            years == 1 ? "1 year since release" : "\(years) years since release"
        case .library:
            years == 1 ? "1 year in your library" : "\(years) years in your library"
        }
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

        return tracks
            .compactMap { track -> TrackBirthday? in
                let origin = origin(of: track)

                guard let anniversary = anniversary(of: origin.date, in: calendar.component(.year, from: date), calendar: calendar),
                      calendar.startOfDay(for: anniversary) == today
                else { return nil }

                // Возраст считается по номерам годов, а не разницей дат: трек, добавленный
                // вечером, празднует с утра — иначе «без пары часов год» округляется в ноль.
                let years = calendar.component(.year, from: date) - calendar.component(.year, from: origin.date)
                guard years >= 1 else { return nil }

                return TrackBirthday(
                    track: track,
                    kind: origin.kind,
                    origin: origin.date,
                    years: years,
                    plays: track.playCount,
                    seconds: listened[track.filename] ?? 0
                )
            }
            .sorted { $0.plays > $1.plays }
            .dedupedByAlbum()
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
                let origin = origin(of: track)

                guard let next = nextAnniversary(of: origin.date, after: today, calendar: calendar),
                      next.years >= 1
                else { return nil }

                return Upcoming(
                    name: track.name,
                    filename: track.filename,
                    album: track.album?.persistentModelID,
                    kind: origin.kind,
                    date: next.date,
                    years: next.years,
                    plays: track.playCount,
                    seconds: listened[track.filename] ?? 0
                )
            }
            // Внутри одного дня вперёд выходит самый заслушанный: он и останется
            // представлять свой альбом после схлопывания.
            .sorted { left, right in
                left.date == right.date ? left.plays > right.plays : left.date < right.date
            }
            .dedupedByAlbum()
            .prefix(limit)
            .map { $0 }
    }

    /// Годовщина без ссылки на модель — всё, что нужно тексту уведомления.
    struct Upcoming {
        let name: String
        let filename: String
        /// Альбом, чтобы годовщина одного релиза не превратилась в дюжину уведомлений.
        let album: PersistentIdentifier?
        let kind: Kind
        let date: Date
        let years: Int
        let plays: Int
        let seconds: TimeInterval

        var body: String {
            let played = plays == 1 ? "1 play" : "\(plays) plays"
            let minutes = Int(seconds / 60)
            let time = minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"

            let age = switch kind {
            case .release:
                years == 1 ? "1 year since release" : "\(years) years since release"
            case .library:
                years == 1 ? "1 year in your library" : "\(years) years in your library"
            }

            return seconds > 0 ? "\(age) • \(played) • \(time)" : "\(age) • \(played)"
        }
    }

    /// От какой даты считать годовщину. Релиз главнее: он у трека один и настоящий,
    /// а день добавления — это про нас, а не про песню.
    private static func origin(of track: Track) -> (date: Date, kind: Kind) {
        if let release = track.album?.release {
            return (release, .release)
        }

        return (track.addedAt, .library)
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

/// Альбом выходит целиком, поэтому годовщина у всех его треков одна и та же.
/// Праздновать её дюжину раз незачем — остаётся самый заслушанный трек, он же
/// и представляет альбом. Треки без альбома остаются каждый сам за себя.
extension Array where Element == TrackBirthday {
    func dedupedByAlbum() -> [TrackBirthday] {
        var seen = Set<PersistentIdentifier>()

        return filter { birthday in
            guard let album = birthday.track.album?.persistentModelID else { return true }
            return seen.insert(album).inserted
        }
    }
}

extension Array where Element == TrackBirthday.Upcoming {
    func dedupedByAlbum() -> [TrackBirthday.Upcoming] {
        var seen = Set<PersistentIdentifier>()

        return filter { birthday in
            guard let album = birthday.album else { return true }
            return seen.insert(album).inserted
        }
    }
}
