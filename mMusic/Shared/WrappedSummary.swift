import Foundation

/// Свод за год: считается из истории прослушиваний одним проходом.
struct WrappedSummary {

    struct Entry: Identifiable {
        /// Как строка называется в списке.
        let name: String
        /// Чем она сопоставляется с библиотекой: у треков — имя файла, у артистов
        /// и жанров — само имя.
        let key: String
        let count: Int
        let seconds: TimeInterval

        var id: String { key }

        /// Минуты, но не в ноль: строка попала в топ года, а «0 min» рядом с ней
        /// выглядит ошибкой счёта.
        var minutes: Int { max(1, Int((seconds / 60).rounded())) }
    }

    let year: Int
    let totalSeconds: TimeInterval
    let plays: Int
    let topTracks: [Entry]
    let topArtists: [Entry]
    let topGenres: [Entry]
    /// Месяц, в котором наслушали больше всего, — по времени, а не по числу
    /// запусков: тем же мерилом, что и топы.
    let busiestMonth: (name: String, seconds: TimeInterval)?
    /// Сколько дней в году музыка вообще играла.
    let activeDays: Int
    /// Самая длинная череда дней подряд.
    let longestStreak: Int
    /// Сколько разного встретилось за год — «широта» вкуса рядом с его глубиной.
    let distinctTracks: Int
    let distinctArtists: Int
    /// Секунды по месяцам, двенадцать чисел начиная с января: из них рисуется
    /// столбчатый год.
    let monthlySeconds: [TimeInterval]

    var totalMinutes: Int { Int(totalSeconds / 60) }
    var totalHours: Int { Int(totalSeconds / 3600) }

    static func make(from events: [PlayEvent], year: Int, calendar: Calendar = .current) -> WrappedSummary {
        let ofYear = events.filter { calendar.component(.year, from: $0.playedAt) == year }

        // Артист считается по каждому своему участию: фит на треке — это тоже
        // прослушивание этого артиста.
        var tracks: [String: Bucket] = [:]
        var artists: [String: Bucket] = [:]
        var genres: [String: Bucket] = [:]
        var monthly = [TimeInterval](repeating: 0, count: 12)
        var days: Set<Date> = []
        var totalSeconds: TimeInterval = 0

        for event in ofYear {
            totalSeconds += event.seconds

            // Ключ трека — имя файла: одноимённые песни разных артистов не должны
            // слипаться в одну строку, а по нему же строка находит трек в
            // библиотеке. У событий, записанных до появления поля, его нет —
            // там ключом остаётся название.
            add(&tracks,
                key: event.trackFilename.isEmpty ? event.trackName : event.trackFilename,
                name: event.trackName,
                seconds: event.seconds)
            add(&genres, key: event.genre.rawValue, name: event.genre.rawValue, seconds: event.seconds)
            for artist in event.artistNames {
                add(&artists, key: artist, name: artist, seconds: event.seconds)
            }

            monthly[calendar.component(.month, from: event.playedAt) - 1] += event.seconds
            days.insert(calendar.startOfDay(for: event.playedAt))
        }

        return WrappedSummary(
            year: year,
            totalSeconds: totalSeconds,
            plays: ofYear.count,
            topTracks: top(tracks),
            topArtists: top(artists),
            topGenres: top(genres, limit: 3),
            busiestMonth: busiestMonth(in: monthly, calendar: calendar),
            activeDays: days.count,
            longestStreak: longestStreak(in: days, calendar: calendar),
            distinctTracks: tracks.count,
            distinctArtists: artists.count,
            monthlySeconds: monthly
        )
    }

    /// Годы, за которые вообще есть что показать.
    static func years(in events: [PlayEvent], calendar: Calendar = .current) -> [Int] {
        Set(events.map { calendar.component(.year, from: $0.playedAt) }).sorted(by: >)
    }

    /// Копилка одной строки топа: складываем по ключу, а показываем имя.
    private struct Bucket {
        let name: String
        var count = 0
        var seconds: TimeInterval = 0

        mutating func add(_ seconds: TimeInterval) {
            count += 1
            self.seconds += seconds
        }
    }

    private static func add(
        _ storage: inout [String: Bucket],
        key: String,
        name: String,
        seconds: TimeInterval
    ) {
        storage[key, default: Bucket(name: name)].add(seconds)
    }

    /// Сортировка по времени, а не по числу запусков: десять целых треков
    /// весомее двадцати брошенных на первой минуте. При равном времени порядок
    /// задаёт имя — иначе две одинаковые строки менялись бы местами на каждой
    /// перерисовке: в словаре порядка нет.
    private static func top(_ storage: [String: Bucket], limit: Int = 5) -> [Entry] {
        storage
            .map { Entry(name: $0.value.name, key: $0.key, count: $0.value.count, seconds: $0.value.seconds) }
            .sorted { ($0.seconds, $1.name) > ($1.seconds, $0.name) }
            .prefix(limit)
            .map { $0 }
    }

    private static func busiestMonth(
        in monthly: [TimeInterval],
        calendar: Calendar
    ) -> (name: String, seconds: TimeInterval)? {
        guard let index = monthly.indices.max(by: { monthly[$0] < monthly[$1] }), monthly[index] > 0
        else { return nil }

        return (calendar.monthSymbols[index], monthly[index])
    }

    /// Самая длинная череда дней подряд. Дни уже уникальны — остаётся пройти по
    /// ним по порядку и считать разрывы. Разница берётся календарём, а не
    /// сутками в секундах: при переводе часов сутки бывают короче и длиннее.
    private static func longestStreak(in days: Set<Date>, calendar: Calendar) -> Int {
        var longest = 0
        var current = 0
        var previous: Date?

        for day in days.sorted() {
            if let previous, calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                current += 1
            } else {
                current = 1
            }

            longest = max(longest, current)
            previous = day
        }

        return longest
    }
}
