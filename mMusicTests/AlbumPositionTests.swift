import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на нумерацию треков в альбоме: дыра в номерах не бросается в глаза сразу,
/// но следующий импорт встаёт на занятое место.
@MainActor
struct AlbumPositionTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeAlbum(trackCount: Int) -> (Album, [Track]) {
        let album = Album(name: "Outrun", type: .LP)
        container.mainContext.insert(album)

        let tracks = (0..<trackCount).map { index -> Track in
            let track = Track(name: "Track \(index)", credits: [], genre: .pop, filename: "track\(index).mp3")
            track.position = index
            track.album = album
            container.mainContext.insert(track)
            return track
        }

        return (album, tracks)
    }

    private func positions(of album: Album) -> [Int] {
        album.tracks.sorted { $0.position < $1.position }.map(\.position)
    }

    /// Главное свойство добавления: то, что уже лежало в альбоме, остаётся.
    /// Раньше состав альбома задавался выбором в листе целиком, и стоило выбору
    /// не совпасть с содержимым — альбом пустел.
    @Test func appendingKeepsWhatWasAlreadyThere() {
        let (album, existing) = makeAlbum(trackCount: 3)

        let newcomer = Track(name: "Newcomer", credits: [], genre: .pop, filename: "new.mp3")
        container.mainContext.insert(newcomer)

        album.append([newcomer])

        #expect(album.tracks.count == 4)
        #expect(existing.allSatisfy { $0.album?.persistentModelID == album.persistentModelID })
        #expect(newcomer.position == 3)
        #expect(positions(of: album) == [0, 1, 2, 3])
    }

    /// Трек с чужого альбома переезжает, а в том альбоме номера смыкаются.
    @Test func appendingMovesTheTrackOutOfItsPreviousAlbum() {
        let (album, _) = makeAlbum(trackCount: 2)

        let other = Album(name: "Midnight", type: .EP)
        container.mainContext.insert(other)

        let moving = Track(name: "Moving", credits: [], genre: .pop, filename: "moving.mp3")
        moving.album = other
        moving.position = 1
        container.mainContext.insert(moving)

        let staying = Track(name: "Staying", credits: [], genre: .pop, filename: "staying.mp3")
        staying.album = other
        staying.position = 0
        container.mainContext.insert(staying)

        album.append([moving])

        #expect(moving.album?.persistentModelID == album.persistentModelID)
        #expect(moving.position == 2)
        #expect(other.tracks.map(\.persistentModelID) == [staying.persistentModelID])
        #expect(positions(of: other) == [0])
    }

    /// Трек, который уже здесь, добавлять некуда: ни дубля, ни переезда в конец.
    @Test func appendingIgnoresTracksThatAreAlreadyInTheAlbum() {
        let (album, tracks) = makeAlbum(trackCount: 3)
        let first = tracks[0]

        album.append([first])

        #expect(album.tracks.count == 3)
        #expect(first.position == 0)
    }

    @Test func deletingFromTheMiddleClosesTheGap() {
        let (album, tracks) = makeAlbum(trackCount: 4)

        album.renumberTracks(excluding: tracks[1])
        container.mainContext.delete(tracks[1])
        // Пока изменения не обработаны, удалённый трек всё ещё числится в альбоме.
        container.mainContext.processPendingChanges()

        #expect(positions(of: album) == [0, 1, 2])
        #expect(album.tracks.sorted { $0.position < $1.position }.map(\.name) == ["Track 0", "Track 2", "Track 3"])
    }

    @Test func renumberingKeepsTheOrder() {
        let (album, tracks) = makeAlbum(trackCount: 3)
        tracks[0].position = 7
        tracks[1].position = 2
        tracks[2].position = 5

        album.renumberTracks()

        #expect(album.tracks.sorted { $0.position < $1.position }.map(\.name) == ["Track 1", "Track 2", "Track 0"])
        #expect(positions(of: album) == [0, 1, 2])
    }

    /// Новый трек получает позицию по числу треков — она обязана быть свободной.
    @Test func nextPositionIsFreeAfterRenumbering() {
        let (album, tracks) = makeAlbum(trackCount: 3)

        album.renumberTracks(excluding: tracks[0])
        container.mainContext.delete(tracks[0])
        container.mainContext.processPendingChanges()

        let newcomer = Track(name: "Newcomer", credits: [], genre: .pop, filename: "new.mp3")
        newcomer.position = album.tracks.count
        newcomer.album = album
        container.mainContext.insert(newcomer)

        #expect(positions(of: album) == [0, 1, 2])
    }
}
