import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на правило обложек: у трека в альбоме обложка всегда альбомная.
/// Правило действует на показ и ничего не переписывает — своя картинка трека
/// остаётся в базе и возвращается, как только альбомной не станет.
@MainActor
struct TrackArtworkTests {

    /// Контейнер хранится в самом наборе тестов: стоит его отпустить — модели
    /// становятся невалидными и обращение к ним роняет процесс.
    private let container: ModelContainer

    private let own = Data([1, 1, 1, 1])
    private let albumCover = Data([2, 2, 2, 2])

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func makeTrack(_ name: String = "Nightcall", artwork: Data? = nil) -> Track {
        let track = Track(name: name, credits: [], genre: .pop, filename: "\(name).mp3", artwork: artwork)
        container.mainContext.insert(track)
        return track
    }

    private func makeAlbum(artwork: Data? = nil) -> Album {
        let album = Album(name: "Night Drive", type: .LP, artwork: artwork)
        container.mainContext.insert(album)
        return album
    }

    @Test func albumCoverOutranksTheTrackOwn() {
        let track = makeTrack(artwork: own)
        makeAlbum(artwork: albumCover).append([track])

        #expect(track.displayArtwork == albumCover)
    }

    /// Главное: правило действует на показ. Своя обложка трека остаётся в базе
    /// целой — её не затирают ни добавлением в альбом, ни сохранением.
    @Test func neverErasesTheTrackOwnCover() throws {
        let track = makeTrack(artwork: own)
        makeAlbum(artwork: albumCover).append([track])
        try container.mainContext.save()

        let stored = try #require(try container.mainContext.fetch(FetchDescriptor<Track>()).first)

        #expect(stored.artwork == own)
        #expect(stored.displayArtwork == albumCover)
    }

    /// Ушёл из альбома — снова свой.
    @Test func theTrackOwnCoverComesBackOutsideTheAlbum() {
        let track = makeTrack(artwork: own)
        let album = makeAlbum(artwork: albumCover)
        album.append([track])

        album.tracks.removeAll { $0.persistentModelID == track.persistentModelID }
        track.album = nil

        #expect(track.displayArtwork == own)
    }

    /// Сняли обложку с альбома — тоже снова свой.
    @Test func theTrackOwnCoverComesBackWhenTheAlbumLosesIts() {
        let track = makeTrack(artwork: own)
        let album = makeAlbum(artwork: albumCover)
        album.append([track])

        album.artwork = nil

        #expect(track.displayArtwork == own)
    }

    /// Обложку альбома не копируют в треки, поэтому её смена видна сразу всем.
    @Test func everyTrackFollowsTheAlbumCover() {
        let first = makeTrack("One", artwork: own)
        let second = makeTrack("Two")
        let album = makeAlbum(artwork: albumCover)
        album.append([first, second])

        let replacement = Data([3, 3, 3, 3])
        album.artwork = replacement

        #expect(first.displayArtwork == replacement)
        #expect(second.displayArtwork == replacement)
    }

    @Test func usesTheTrackOwnCoverWhenTheAlbumHasNone() {
        let track = makeTrack(artwork: own)
        makeAlbum().append([track])

        #expect(track.displayArtwork == own)
    }

    @Test func usesTheTrackOwnCoverWithoutAnAlbum() {
        #expect(makeTrack(artwork: own).displayArtwork == own)
    }

    @Test func staysEmptyWhenThereIsNoCoverAnywhere() {
        let track = makeTrack()
        makeAlbum().append([track])

        #expect(track.displayArtwork == nil)
    }

    /// Переезд в другой альбом — обложка нового.
    @Test func takesTheCoverOfTheAlbumItMovesTo() {
        let track = makeTrack(artwork: own)
        makeAlbum(artwork: albumCover).append([track])

        let other = Album(name: "Paper Boats", type: .LP, artwork: Data([4, 4, 4, 4]))
        container.mainContext.insert(other)
        other.append([track])

        #expect(track.displayArtwork == Data([4, 4, 4, 4]))
    }
}
