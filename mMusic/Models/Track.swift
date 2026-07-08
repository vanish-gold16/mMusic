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
        credits.sorted { $0.position < $1.position }
            .map { $0.artist }
    }
    var artistNames: [String] {
        artists.map(\.name)
    }
    var genre: Genre
    var filename: String
    var isFavourite = false
    
    var addedAt: Date = Date.now
    
    @Attribute(.externalStorage) var artwork: Data?

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
