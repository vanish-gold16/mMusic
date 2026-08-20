import Foundation

/// Разовая пересортировка плейлиста. Не режим отображения, а переписывание
/// позиций: порядок в плейлисте — часть его содержимого, и он остаётся ручным.
enum PlaylistSort: String, CaseIterable, Identifiable {
    case name = "Name"
    case album = "Album"
    case mostPlayed = "Most played"
    case recentlyAdded = "Recently added"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .name: "textformat"
        case .album: "square.stack"
        case .mostPlayed: "flame"
        case .recentlyAdded: "sparkles"
        }
    }

    func sorted(_ items: [TrackPlaylistItem]) -> [TrackPlaylistItem] {
        switch self {
        case .name:
            items.sorted { $0.track.name.localizedCaseInsensitiveCompare($1.track.name) == .orderedAscending }
        case .album:
            // Внутри альбома — по номеру трека, иначе сортировка рвала бы пластинки.
            items.sorted {
                let left = $0.track.album?.name ?? ""
                let right = $1.track.album?.name ?? ""
                if left != right { return left.localizedCaseInsensitiveCompare(right) == .orderedAscending }
                return $0.track.position < $1.track.position
            }
        case .mostPlayed:
            items.sorted { $0.track.playCount > $1.track.playCount }
        case .recentlyAdded:
            items.sorted { $0.track.addedAt > $1.track.addedAt }
        }
    }
}
