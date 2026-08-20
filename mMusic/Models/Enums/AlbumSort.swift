import Foundation

enum AlbumSort: String, CaseIterable, Identifiable {
    case dateAdded = "Date Added"
    case name = "Name"
    case release = "Release Date"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dateAdded: "clock"
        case .name: "textformat"
        case .release: "calendar"
        }
    }
}
