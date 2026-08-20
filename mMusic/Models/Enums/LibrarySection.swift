import Foundation

/// Раздел библиотеки. Раньше это были четыре отдельных экрана, до которых вели
/// два одинаковых бургер-меню; теперь один экран с переключателем.
enum LibrarySection: String, CaseIterable, Identifiable {
    case albums
    case playlists
    case artists
    case smart

    var id: String { rawValue }

    var title: String {
        switch self {
        case .albums: "Albums"
        case .playlists: "Playlists"
        case .artists: "Artists"
        case .smart: "Smart"
        }
    }
}
