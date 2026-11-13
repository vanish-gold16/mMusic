import SwiftData
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

    /// Сравнение и хеш написаны руками, хотя компилятор умеет выводить их сам.
    /// Выведенные ломали сборку: Swift 6.4 (Xcode 27.2) иногда «не видит»,
    /// что `Album` и `Artist` сравнимы. Сравнимыми их делает макрос `@Model`,
    /// и успел ли он раскрыться к этому моменту, зависит от того, как сборка
    /// разложила файлы по заданиям компилятора. Хватало добавить в проект
    /// один любой файл — и всё падало с «'Artist' does not conform to 'Equatable'».
    /// Руками написанному сравнению это не грозит: ему не нужно, чтобы компилятор
    /// заранее знал о сравнимости моделей.
    ///
    /// Модели сравниваются ровно так, как их сравнивает сама SwiftData:
    /// равны, только если это один и тот же объект (`===`), а хеш берётся
    /// от `persistentModelID`. Поведение то же, что было у выведенных.
    static func == (lhs: MusicRoute, rhs: MusicRoute) -> Bool {
        switch (lhs, rhs) {
        case (.album(let a), .album(let b)): a === b
        case (.artist(let a), .artist(let b)): a === b
        // Без `default`: новый case не соберётся, пока его не впишут и сюда.
        case (.album, _), (.artist, _): false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .album(let album): hasher.combine(album.persistentModelID)
        case .artist(let artist): hasher.combine(artist.persistentModelID)
        }
    }

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
