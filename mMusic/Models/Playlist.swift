import Foundation
import SwiftData

@Model
class Playlist {
    var name: String
    var playlistDescription: String
    @Relationship(deleteRule: .cascade, inverse: \TrackPlaylistItem.playlist)
    var items: [TrackPlaylistItem]
    var orderedTracks: [Track] {
        items.sorted { $0.position < $1.position }
            .map(\.track)
    }
    var isPinned = false
    var isFavourite = false
    /// Когда этот плейлист последний раз запускали. Считается именно запуск плейлиста,
    /// а не прослушивание входящего в него трека из библиотеки.
    var lastPlayedAt: Date?
    
    @Attribute(.externalStorage) var artwork: Data?
    
    /// Когда в плейлист последний раз что-то положили.
    var lastAddedAt: Date? {
        items.map(\.addedAt).max()
    }

    func markPlayed() {
        lastPlayedAt = .now
    }
    
    init(name: String, playlistDescription: String = "", items: [TrackPlaylistItem], isPinned: Bool = false, artwork: Data? = nil) {
        self.name = name
        self.playlistDescription = playlistDescription
        self.items = items
        self.isPinned = isPinned
        self.artwork = artwork
    }
    
}

extension Array where Element == Playlist {

    /// Порядок для просмотра — библиотека, поиск, всё, где плейлисты листают:
    /// закреплённые сверху, а внутри каждой группы — по свежести запуска.
    /// Ни разу не запускавшиеся уходят вниз, при равенстве работает имя.
    var byLastPlayed: [Playlist] {
        sorted { left, right in
            if left.isPinned != right.isPinned { return left.isPinned }

            let leftPlayed = left.lastPlayedAt ?? .distantPast
            let rightPlayed = right.lastPlayedAt ?? .distantPast
            if leftPlayed != rightPlayed { return leftPlayed > rightPlayed }

            return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
        }
    }

    /// Порядок для «куда положить»: сверху тот плейлист, в который недавно
    /// добавляли трек. Закрепление здесь ни при чём — вопрос не «что слушать»,
    /// а «куда это обычно кладут».
    var byLastAdded: [Playlist] {
        sorted { left, right in
            let leftAdded = left.lastAddedAt ?? .distantPast
            let rightAdded = right.lastAddedAt ?? .distantPast
            if leftAdded != rightAdded { return leftAdded > rightAdded }

            return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
        }
    }
}
