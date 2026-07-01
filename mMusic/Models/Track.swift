import Foundation
import SwiftData

@Model
class Track {
    var name: String
    var artist: String
    var genre: Genre
    var filename: String
    var isFavourite = false
    
    @Attribute(.externalStorage) var artwork: Data?

    init(name: String, artist: String, genre: Genre, filename: String, isFavourite: Bool = false, artwork: Data? = nil) {
        self.name = name
        self.artist = artist
        self.genre = genre
        self.filename = filename
        self.isFavourite = isFavourite
        self.artwork = artwork
    }

}
