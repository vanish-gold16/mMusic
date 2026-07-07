import Foundation
import SwiftData

@Model
class Credit {
    var artist: Artist
    var role: CreditRole
    var position: Int
    var track: Track?
    var album: Album?
    
    init(artist: Artist, role: CreditRole = .main, position: Int, track: Track? = nil, album: Album? = nil) {
        self.artist = artist
        self.role = role
        self.position = position
        self.track = track
        self.album = album
    }
}
