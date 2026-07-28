import Foundation
import SwiftData
import SwiftUI

@Model
class Track {
    var name: String
    var album: Album?
    @Relationship(deleteRule: .cascade, inverse: \Credit.track)
    var credits: [Credit]
    var artists: [Artist] {
        let inherited = album?.artists ?? []
        let own = credits.sorted { $0.position < $1.position }
            .map { $0.artist }
        
        var seen = Set<String>()
        return (inherited + own).filter { seen.insert($0.name).inserted }
    }
    var artistNames: [String] {
        artists.map(\.name)
    }
    var genre: Genre
    var filename: String
    var isFavourite = false
    var position: Int = 0
    
    var addedAt: Date = Date.now
    
    @Attribute(.externalStorage) var artwork: Data?
    var displayArtwork: Data? {
        artwork ?? album?.artwork
    }

    init(name: String, album: Album? = nil, credits: [Credit], genre: Genre, filename: String, isFavourite: Bool = false, artwork: Data? = nil) {
        self.name = name
        self.album = album
        self.credits = credits
        self.genre = genre
        self.filename = filename
        self.isFavourite = isFavourite
        self.artwork = artwork
    }

}
