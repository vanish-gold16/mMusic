import Foundation
import SwiftData

@Model
class Track {
    var name: String
    var artist: String
    let filename: String
    var isFavourite = false
    
    init(name: String, artist: String, filename: String, isFavourite: Bool = false) {
        self.name = name
        self.artist = artist
        self.filename = filename
        self.isFavourite = isFavourite
    }
}
