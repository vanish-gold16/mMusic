import Foundation
import SwiftData
import SwiftUI

@Model
class Track {
    var name: String
    var album: Album
    @Relationship(deleteRule: .cascade, inverse: \Credit.track)
    var credits: [Credit]
    var genre: Genre
    var filename: String
    var isFavourite = false
    
    var addedAt: Date = Date.now
    
    @Attribute(.externalStorage) var artwork: Data?

    init(name: String, album: Album, credits: [Credit], genre: Genre, filename: String, isFavourite: Bool = false, artwork: Data? = nil) {
        self.name = name
        self.album = album
        self.credits = credits
        self.genre = genre
        self.filename = filename
        self.isFavourite = isFavourite
        self.artwork = artwork
    }

}
