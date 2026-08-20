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
