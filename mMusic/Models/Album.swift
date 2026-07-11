import Foundation
import SwiftData

@Model
class Album {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Track.album)
    var tracks: [Track]
    @Relationship(deleteRule: .cascade, inverse: \Credit.album)
    var credits: [Credit]
    var artists: [Artist] {
        credits.sorted { $0.position < $1.position }
            .map(\.artist)
    }
    var artistNames: [String] {
        artists.map(\.name)
    }
    var genres: [Genre] {
        let counts = tracks.reduce(into: [Genre: Int]()) { counts, track in
            counts[track.genre, default: 0] += 1
        }
        return counts.keys.sorted {
            if counts[$0]! != counts[$1]! {
                return counts[$0]! > counts[$1]!
            }
            return $0.rawValue < $1.rawValue
        }
    }
    var release: Date?
    
    var addedAt: Date = Date.now
    
    @Attribute(.externalStorage) var artwork: Data?
    
    init(name: String, tracks: [Track] = [], credits: [Credit] = [], release: Date? = nil, artwork: Data? = nil) {
        self.name = name
        self.tracks = tracks
        self.credits = credits
        self.artwork = artwork
    }
}
