import Foundation
import SwiftData

@Model
class Album {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Track.album)
    var tracks: [Track]
    @Relationship(deleteRule: .cascade, inverse: \Credit.album)
    var credits: [Credit]
    
    @Attribute(.externalStorage) var artwork: Data?
    
    init(name: String, tracks: [Track] = [], credits: [Credit] = [], artwork: Data? = nil) {
        self.name = name
        self.tracks = tracks
        self.credits = credits
        self.artwork = artwork
    }
}
