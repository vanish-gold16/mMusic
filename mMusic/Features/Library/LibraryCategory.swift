import SwiftUI
enum LibraryCategory: String, CaseIterable {
    case playlists = "Playlists"
    case albums = "Albums"
    case artists = "Artists"

    var icon: String {
        switch self {
        case .playlists:
            return "music.note.list"
        case .albums:
            return "square.stack"
        case .artists:
            return "music.note"
        }
    }
}
