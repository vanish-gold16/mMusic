import Foundation
import SwiftData

@Model
class TrackPlaylistItem {
    var track: Track
    var playlist: Playlist
    var position: Int
    /// Когда этот трек положили в плейлист. По самой свежей из этих дат плейлисты
    /// выстраиваются на экране «добавить в плейлист»: куда недавно клали, туда
    /// скорее всего кладут и сейчас.
    ///
    /// У строк, созданных до появления поля, дата будет временем обновления —
    /// прошлое приложение её просто не хранило.
    var addedAt: Date = Date.now

    init(track: Track, playlist: Playlist, position: Int, addedAt: Date = .now) {
        self.track = track
        self.playlist = playlist
        self.position = position
        self.addedAt = addedAt
    }
}
