import Foundation

/// Свод за год: считается из истории прослушиваний одним проходом.
struct WrappedSummary {

    struct Entry: Identifiable {
        let name: String
        let count: Int
        let seconds: TimeInterval

        var id: String { name }
    }

    let year: Int
    let totalSeconds: TimeInterval
    let plays: Int
    let topTracks: [Entry]
    let topArtists: [Entry]
    let topGenres: [Entry]
    let busiestMonth: (name: String, plays: Int)?
    /// Сколько дней в году музыка вообще играла.
    let activeDays: Int

    var totalMinutes: Int { Int(totalSeconds / 60) }
    var totalHours: Int { Int(totalSeconds / 3600) }

    static func make(from events: [PlayEvent], year: Int) -> WrappedSummary {
        let calendar = Calendar.current
        let ofYear = events.filter { calendar.component(.year, from: $0.playedAt) == year }

        // Артист считается по каждому своему участию: фит на треке — это тоже
        // прослушивание этого артиста.
        var tracks: [String: (count: Int, seconds: TimeInterval)] = [:]
        var artists: [String: (count: Int, seconds: TimeInterval)] = [:]
        var genres: [String: (count: Int, seconds: TimeInterval)] = [:]
        var months: [Int: Int] = [:]
        var days: Set<DateComponents> = []
        var totalSeconds: TimeInterval = 0

        for event in ofYear {
            totalSeconds += event.seconds

            add(&tracks, key: event.trackName, seconds: event.seconds)
            add(&genres, key: event.genre.rawValue, seconds: event.seconds)
            for artist in event.artistNames {
                add(&artists, key: artist, seconds: event.seconds)
            }

            months[calendar.component(.month, from: event.playedAt), default: 0] += 1
            days.insert(calendar.dateComponents([.year, .month, .day], from: event.playedAt))
        }

        let busiest = months.max { $0.value < $1.value }

        return WrappedSummary(
            year: year,
            totalSeconds: totalSeconds,
            plays: ofYear.count,
            topTracks: top(tracks),
            topArtists: top(artists),
            topGenres: top(genres, limit: 3),
            busiestMonth: busiest.map { (calendar.monthSymbols[$0.key - 1], $0.value) },
            activeDays: days.count
        )
    }

    /// Годы, за которые вообще есть что показать.
    static func years(in events: [PlayEvent]) -> [Int] {
        let calendar = Calendar.current
        return Set(events.map { calendar.component(.year, from: $0.playedAt) }).sorted(by: >)
    }

    private static func add(
        _ storage: inout [String: (count: Int, seconds: TimeInterval)],
        key: String,
        seconds: TimeInterval
    ) {
        let current = storage[key] ?? (0, 0)
        storage[key] = (current.count + 1, current.seconds + seconds)
    }

    /// Сортировка по времени, а не по числу запусков: десять целых треков
    /// весомее двадцати брошенных на первой минуте.
    private static func top(
        _ storage: [String: (count: Int, seconds: TimeInterval)],
        limit: Int = 5
    ) -> [Entry] {
        storage
            .map { Entry(name: $0.key, count: $0.value.count, seconds: $0.value.seconds) }
            .sorted { $0.seconds > $1.seconds }
            .prefix(limit)
            .map { $0 }
    }
}
