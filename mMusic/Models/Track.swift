import Foundation

struct Track: Identifiable, Codable {
    let id = UUID()
    var name: String
    var artist: String
    let filename: String
}
