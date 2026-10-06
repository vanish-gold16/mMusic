import Foundation

/// Подборка, которая собирается сама из того, что уже знает модель:
/// счётчик прослушиваний, дата добавления, дата последнего запуска, звезда.
/// Никаких новых полей — только правила поверх существующих.
enum SmartPlaylist: String, CaseIterable, Identifiable {
    case favourites
    case mostPlayed
    case recentlyAdded
    case forgotten
    case neverPlayed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favourites: "Favourites"
        case .mostPlayed: "Most played"
        case .recentlyAdded: "Recently added"
        case .forgotten: "Forgotten"
        case .neverPlayed: "Never played"
        }
    }

    var subtitle: String {
        switch self {
        case .favourites: "Everything you starred"
        case .mostPlayed: "Your heavy rotation"
        case .recentlyAdded: "Newest in the library"
        case .forgotten: "Loved once, untouched for a month"
        case .neverPlayed: "Imported but never started"
        }
    }

    /// Надпись на наклейке поверх обложки — как наклейки на пластинках
    /// в магазине: «тяжёлая ротация», «только привезли». Перенос строки —
    /// где ему место на круглой наклейке.
    var sticker: String {
        switch self {
        case .favourites: "STARRED"
        case .mostPlayed: "HEAVY\nROTATION"
        case .recentlyAdded: "JUST\nIN"
        case .forgotten: "DUSTY"
        case .neverPlayed: "STILL\nSEALED"
        }
    }

    var systemImage: String {
        switch self {
        case .favourites: "star"
        case .mostPlayed: "flame"
        case .recentlyAdded: "sparkles"
        case .forgotten: "hourglass"
        case .neverPlayed: "seal"
        }
    }

    /// Длинные подборки режутся: полсотни треков — уже больше, чем слушают за раз,
    /// а рисовать тысячу строк незачем.
    private var limit: Int { 50 }

    func tracks(from all: [Track]) -> [Track] {
        switch self {
        case .favourites:
            all.filter(\.isFavourite)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        case .mostPlayed:
            Array(
                all.filter { $0.playCount > 0 }
                    .sorted { $0.playCount > $1.playCount }
                    .prefix(limit)
            )

        case .recentlyAdded:
            Array(all.sorted { $0.addedAt > $1.addedAt }.prefix(limit))

        case .forgotten:
            // Именно забытое, а не неслушанное: трек когда-то ставили, но давно.
            Array(
                all.compactMap { track -> (Track, Date)? in
                    guard let last = track.lastPlayedAt, last < Self.monthAgo else { return nil }
                    return (track, last)
                }
                .sorted { $0.1 < $1.1 }
                .map(\.0)
                .prefix(limit)
            )

        case .neverPlayed:
            all.filter { $0.lastPlayedAt == nil }
                .sorted { $0.addedAt > $1.addedAt }
        }
    }

    private static var monthAgo: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
    }
}
