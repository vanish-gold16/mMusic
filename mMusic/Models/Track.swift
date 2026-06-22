import Foundation

struct Track: Identifiable {
    let id = UUID()
    var name: String
    var artist: String
    let filename: String
}
