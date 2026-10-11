import SwiftUI

/// Куда ведут «Go to Album» и «Go to Artist», когда переход делает не сама
/// строка, а кто-то снаружи стопки: мини-плеер над вкладками, очередь,
/// меню плеера. Значение кладётся в путь навигации, а экран по нему строит
/// `musicRoutes()` у корня стопки.
///
/// `nonisolated` — потому что значение кладётся в `NavigationPath`, а тот
/// требует сравнения, доступного с любого потока. По умолчанию типы в проекте
/// живут на главном потоке, и сравнение тоже было бы только там.
nonisolated enum MusicRoute: Hashable {
    case album(Album)
    case artist(Artist)

    /// Экран, который открывается по этому значению.
    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .album(let album):
            AlbumView(album: album)
        case .artist(let artist):
            ArtistView(artist: artist)
        }
    }
}

extension View {

    /// Экраны для `MusicRoute`. Вешается на корень каждой стопки, куда
    /// кладут такие значения: на вкладки и на стопку плеера.
    func musicRoutes() -> some View {
        navigationDestination(for: MusicRoute.self) { route in
            route.destination
        }
    }
}

/// «Go to Artist» в меню. Артист один — сразу пункт; несколько — подменю
/// с именами: «Go to Artist» без ответа «к которому» бессмыслен.
struct GoToArtistItems: View {

    let artists: [Artist]
    let onSelect: (Artist) -> Void

    var body: some View {
        if artists.count == 1, let artist = artists.first {
            Button {
                onSelect(artist)
            } label: {
                Label("Go to Artist", systemImage: "person")
            }
        } else if !artists.isEmpty {
            Menu {
                ForEach(artists) { artist in
                    Button(artist.name) {
                        onSelect(artist)
                    }
                }
            } label: {
                Label("Go to Artist", systemImage: "person.2")
            }
        }
    }
}
