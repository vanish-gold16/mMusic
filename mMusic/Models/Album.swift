import Foundation
import SwiftData

@Model
class Album {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Track.album)
    var tracks: [Track]
    
    @Attribute(.externalStorage) var artwork: Data?
    
    init(name: String, tracks: [Track] = [], artwork: Data? = nil) {
        self.name = name
        self.tracks = tracks
        self.artwork = artwork
    }
}
