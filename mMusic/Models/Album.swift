import Foundation
import SwiftData

@Model
class Album {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Track.album)
    var tracks: [Track]
    var type: AlbumType
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
    
    init(name: String, tracks: [Track] = [], type: AlbumType = .single, credits: [Credit] = [], release: Date? = nil, artwork: Data? = nil) {
        self.name = name
        self.tracks = tracks
        self.type = type
        self.credits = credits
        self.release = release
        self.artwork = artwork
    }
    
    enum AlbumType: String, Codable {
        case single = "single"
        case EP = "EP"
        case LP = "LP"
    }
    
}
