import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на починку номеров. Пересчёт трогает только сами номера: ни треков,
/// ни их порядка он менять не должен — иначе лечение хуже болезни.
@MainActor
struct AlbumNumberingTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Альбом с заранее заданными номерами — ровно то, что оставила после себя
    /// прежняя нумерация.
    private func makeAlbum(name: String = "Night Drive", positions: [Int]) -> (Album, [Track]) {
        let album = Album(name: name, type: .LP)
        container.mainContext.insert(album)

        let tracks = positions.enumerated().map { index, position -> Track in
            let track = Track(name: "Track \(index)", credits: [], genre: .pop, filename: "track\(index).mp3")
            container.mainContext.insert(track)
            track.album = album
            track.position = position
            return track
        }

        return (album, tracks)
    }

    private func order(of album: Album) -> [String] {
        album.tracks.sorted { $0.position < $1.position }.map(\.name)
    }

    /// Тот самый случай: единственный трек альбома с номером 1 показывал «2».
    @Test func bringsALoneTrackBackToTheFirstNumber() {
        let (album, tracks) = makeAlbum(positions: [1])

        #expect(AlbumNumbering.repair(in: container.mainContext) == 1)
        #expect(tracks[0].position == 0)
        #expect(album.isNumberedInOrder)
    }

    @Test func closesTheGapWhenNumberingStartsFromTwo() {
        let (_, tracks) = makeAlbum(positions: [1, 2, 3])

        AlbumNumbering.repair(in: container.mainContext)

        #expect(tracks.map(\.position) == [0, 1, 2])
    }

    /// Порядок — главное: пересчёт смыкает номера, но не переставляет треки.
    @Test func keepsTheOrderItFound() {
        let (album, _) = makeAlbum(positions: [7, 2, 5])

        AlbumNumbering.repair(in: container.mainContext)

        #expect(order(of: album) == ["Track 1", "Track 2", "Track 0"])
        #expect(album.isNumberedInOrder)
    }

    /// Исправный альбом проход не трогает — и номера, и порядок остаются те же.
    @Test func leavesAHealthyAlbumAlone() {
        let (album, tracks) = makeAlbum(positions: [0, 1, 2])

        #expect(AlbumNumbering.repair(in: container.mainContext) == 0)
        #expect(tracks.map(\.position) == [0, 1, 2])
        #expect(order(of: album) == ["Track 0", "Track 1", "Track 2"])
    }

    /// Одинаковые номера пересчёт разводит, и делает это одинаково при каждом
    /// проходе: порядок задают дата добавления и имя файла, а не случай.
    @Test func splitsEqualNumbersTheSameWayEveryTime() {
        let (album, _) = makeAlbum(positions: [0, 0, 0])

        AlbumNumbering.repair(in: container.mainContext)
        let first = order(of: album)

        // Второй проход по уже исправленному альбому ничего не меняет.
        #expect(AlbumNumbering.repair(in: container.mainContext) == 0)
        #expect(order(of: album) == first)
        #expect(album.isNumberedInOrder)
    }

    /// Починка идёт по всей библиотеке, а не по одному альбому.
    @Test func repairsEveryBrokenAlbumAndCountsThem() {
        _ = makeAlbum(name: "First", positions: [1, 2])
        _ = makeAlbum(name: "Second", positions: [0, 1])
        _ = makeAlbum(name: "Third", positions: [3])

        #expect(AlbumNumbering.repair(in: container.mainContext) == 2)

        let albums = (try? container.mainContext.fetch(FetchDescriptor<Album>())) ?? []
        let healthy = albums.filter(\.isNumberedInOrder).count
        #expect(healthy == albums.count)
    }

    /// Ничего не пропадает: сколько треков было в альбоме, столько и осталось.
    @Test func neverLosesTracks() throws {
        let (album, tracks) = makeAlbum(positions: [4, 9, 1])
        try container.mainContext.save()

        AlbumNumbering.repair(in: container.mainContext)
        try container.mainContext.save()

        let stored = try container.mainContext.fetch(FetchDescriptor<Track>())
        let inAlbum = stored.filter { $0.album?.persistentModelID == album.persistentModelID }.count

        #expect(stored.count == tracks.count)
        #expect(album.tracks.count == tracks.count)
        #expect(inAlbum == tracks.count)
    }

    @Test func doesNotMindAnEmptyAlbum() {
        let album = Album(name: "Empty", type: .single)
        container.mainContext.insert(album)

        #expect(album.isNumberedInOrder)
        #expect(AlbumNumbering.repair(in: container.mainContext) == 0)
    }
}
