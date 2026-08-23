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
