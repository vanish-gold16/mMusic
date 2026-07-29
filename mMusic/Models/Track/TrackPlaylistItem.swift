import Foundation
import SwiftData

@Model
class TrackPlaylistItem {
    var track: Track
    var playlist: Playlist
    var position: Int
    
    init(track: Track, playlist: Playlist, position: Int) {
        self.track = track
        self.playlist = playlist
        self.position = position
    }
}
