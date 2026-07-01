import Foundation
import SwiftData
import SwiftUI

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
    
    func edit(name: String?, artist: String?, genre: Genre?, filename: String, artwork: Data?) {
        if name != nil {
            self.name = name!
        }
        if artist != nil {
            self.artist = artist!
        }
        if genre != nil {
            self.genre = genre!
        }
        
        self.filename = filename
        
        if artwork != nil {
            self.artwork = artwork
        }
    }

}
