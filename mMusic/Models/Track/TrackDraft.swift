import Foundation

struct TrackDraft: Identifiable {
    let id = UUID()
    var name: String
    var genre: Genre = .pop
    var artists: [ArtistDraft] = []
    var stagedURL: URL
}
