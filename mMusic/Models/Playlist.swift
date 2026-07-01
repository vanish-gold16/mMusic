import Foundation
import SwiftData

@Model
class Playlist {
    var name: String
    var tracks: [Track]
    var isPinned = false
    
    @Attribute(.externalStorage) var artwork: Data?
    
    init(name: String, tracks: [Track], isPinned: Bool = false, artwork: Data? = nil) {
        self.name = name
        self.tracks = tracks
        self.isPinned = isPinned
        self.artwork = artwork
    }
    
}
