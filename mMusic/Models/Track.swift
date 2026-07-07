import Foundation
import SwiftData
import SwiftUI

@Model
class Track {
    var name: String
    @Relationship(deleteRule: .nullify, inverse: \Artist.tracks)
    var artists: [Artist]
    var album: Album
    var genre: Genre
    var filename: String
    var isFavourite = false
    
    var addedAt: Date = Date.now
    
    @Attribute(.externalStorage) var artwork: Data?

    init(name: String, artists: [Artist], album: Album, genre: Genre, filename: String, isFavourite: Bool = false, artwork: Data? = nil) {
        self.name = name
        self.artists = artists
        self.album = album
        self.genre = genre
        self.filename = filename
        self.isFavourite = isFavourite
        self.artwork = artwork
    }

}
