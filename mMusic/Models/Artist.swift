import Foundation
import SwiftData

@Model
class Artist {
    var name: String
    var tracks: [Track]
}
