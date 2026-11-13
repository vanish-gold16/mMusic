import Foundation
import SwiftData

struct TrackDraft: Identifiable {
    let id = UUID()
    var name: String
    var genre: Genre = .pop
    var artists: [ArtistDraft] = []
    var stagedURL: URL
    /// Файл в «Файлах», из которого сделан черновик. Нужен, чтобы убрать оригинал
    /// после сохранения альбома — но не раньше: создание можно и отменить.
    var originalURL: URL?
    var sourceTrack: PersistentIdentifier?
    /// Сингл из библиотеки с той же песней, что и в файле, — см. `SingleMatch`.
    /// Тогда в альбом переезжает он сам, со всей своей историей, а файл не
    /// импортируется. nil — совпадения нет или его отменили: файл станет новым треком.
    var existingTrack: PersistentIdentifier?
    /// На какой пластинке будущего альбома лежит трек. nil — только что добавлен
    /// и ещё не разложен: такой ложится на последнюю пластинку.
    var disc: Int?
    /// Длительность файла — для толщины кольца на превью пластинки и для
    /// «43 MIN» в паспорте. 0 — ещё не прочитана; у трека из библиотеки её
    /// берут из самого трека.
    var duration: TimeInterval = 0
}

extension [TrackDraft] {

    /// Жанр будущего альбома в форме сборки — по жанрам черновиков. Жанр
    /// черновика — это жанр, с которым трек ляжет в альбом (см. `CreateAlbumView.save`).
    var tracksGenre: AlbumGenre {
        AlbumGenre(map(\.genre))
    }

    /// Ставит жанр всем черновикам. В базу пока ничего не пишется — только
    /// при «Create album».
    mutating func setGenre(_ genre: Genre) {
        for index in indices where self[index].genre != genre {
            self[index].genre = genre
        }
    }
}
