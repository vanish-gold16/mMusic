import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на переезд сингла в альбом. Ошибка здесь не падает, а тихо теряет:
/// обложку, гостя в авторах, а при ложном совпадении — целую песню.
@MainActor
struct SingleMoveTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    /// Сингл, как его заводит импорт: альбом из одного трека, авторы и обложка — на альбоме.
    @discardableResult
    private func makeSingle(
        _ name: String,
        by artists: [(String, CreditRole)],
        type: Album.AlbumType = .single,
        cover: Data? = nil,
        playCount: Int = 0
    ) -> Track {
        let album = Album(name: name, type: type, artwork: cover)
        context.insert(album)

        let track = Track(name: name, album: album, credits: [], genre: .pop, filename: "\(name)-\(UUID()).mp3")
        track.playCount = playCount
        context.insert(track)

        for (position, (artist, role)) in artists.enumerated() {
            let model = context.findOrCreateArtist(named: artist)
            context.insert(Credit(artist: model, role: role, position: position, album: album))
        }

        return track
    }

    private func makeAlbum(_ name: String, by artist: String) -> Album {
        let album = Album(name: name, type: .LP)
        context.insert(album)
        context.insert(Credit(artist: context.findOrCreateArtist(named: artist), position: 0, album: album))
        return album
    }

    private var albums: [Album] {
        (try? context.fetch(FetchDescriptor<Album>())) ?? []
    }

    // MARK: - Узнавание

    @Test func guestsInTheTitleDoNotMakeAnotherSong() {
        #expect(SingleMatch.normalizedTitle("Nightcall (feat. Lovefoxxx)") == "nightcall")
        #expect(SingleMatch.normalizedTitle("Nightcall [ft. Lovefoxxx]") == "nightcall")
        #expect(SingleMatch.normalizedTitle("Nightcall feat. Lovefoxxx") == "nightcall")
        #expect(SingleMatch.normalizedTitle("  NIGHTCALL ") == "nightcall")
        #expect(SingleMatch.normalizedTitle("Nightcall (Remix)") == "nightcall (remix)")
        #expect(SingleMatch.normalizedTitle("Café") == SingleMatch.normalizedTitle("cafe"))
    }

    @Test func findsTheSingleBySameTitleAndArtist() {
        let single = makeSingle("Nightcall", by: [("Kavinsky", .main), ("Lovefoxxx", .featured)])
        let library = (try? context.fetch(FetchDescriptor<Track>())) ?? []

        let found = SingleMatch.track(titled: "Nightcall (feat. Lovefoxxx)", by: ["Kavinsky"], among: library)

        #expect(found?.persistentModelID == single.persistentModelID)
    }

    @Test func doesNotGuessWithoutACommonArtist() {
        makeSingle("Intro", by: [("Kavinsky", .main)])
        let library = (try? context.fetch(FetchDescriptor<Track>())) ?? []

        #expect(SingleMatch.track(titled: "Intro", by: ["The xx"], among: library) == nil)
        #expect(SingleMatch.track(titled: "Intro", by: [], among: library) == nil)
    }

    @Test func leavesTracksOfBiggerRecordsAlone() {
        makeSingle("Outrun", by: [("Kavinsky", .main)], type: .LP)
        let library = (try? context.fetch(FetchDescriptor<Track>())) ?? []

        #expect(SingleMatch.track(titled: "Outrun", by: ["Kavinsky"], among: library) == nil)
    }

    @Test func aRemixIsAnotherSong() {
        makeSingle("Nightcall", by: [("Kavinsky", .main)])
        let library = (try? context.fetch(FetchDescriptor<Track>())) ?? []

        #expect(SingleMatch.track(titled: "Nightcall (Remix)", by: ["Kavinsky"], among: library) == nil)
    }

    @Test func aDuplicatedSingleGivesTheOneWithHistory() {
        makeSingle("Nightcall", by: [("Kavinsky", .main)], playCount: 2)
        let played = makeSingle("Nightcall", by: [("Kavinsky", .main)], playCount: 40)
        let library = (try? context.fetch(FetchDescriptor<Track>())) ?? []

        let found = SingleMatch.track(titled: "Nightcall", by: ["Kavinsky"], among: library)

        #expect(found?.persistentModelID == played.persistentModelID)
    }

    // MARK: - Переезд

    @Test func theTrackKeepsTheSinglesCoverAndGuests() {
        let cover = Data([1, 2, 3])
        let track = makeSingle("Nightcall", by: [("Kavinsky", .main), ("Lovefoxxx", .featured)], cover: cover)
        let album = makeAlbum("Outrun", by: "Kavinsky")

        album.append([track])

        #expect(track.album?.persistentModelID == album.persistentModelID)
        #expect(track.artwork == cover)
        // Автор альбома не продублирован, гость сингла остался гостем трека.
        #expect(track.artistNames == ["Kavinsky", "Lovefoxxx"])
        #expect(track.credits.map(\.artist.name) == ["Lovefoxxx"])
        #expect(track.credits.first?.role == .featured)
    }

    @Test func theSinglesArtistsStayAheadOfTheTracksOwnGuests() {
        let track = makeSingle("Nightcall", by: [("Kavinsky", .main), ("Lovefoxxx", .main)])
        context.insert(Credit(artist: context.findOrCreateArtist(named: "Guest"), role: .featured, position: 0, track: track))
        let album = makeAlbum("Outrun", by: "Kavinsky")

        album.append([track])

        #expect(track.artistNames == ["Kavinsky", "Lovefoxxx", "Guest"])
    }

    @Test func anOwnCoverIsNotOverwritten() {
        let track = makeSingle("Nightcall", by: [("Kavinsky", .main)], cover: Data([1]))
        track.artwork = Data([9])
        let album = makeAlbum("Outrun", by: "Kavinsky")

        album.append([track])

        #expect(track.artwork == Data([9]))
    }

    @Test func theEmptiedSingleLeavesTheLibrary() throws {
        let track = makeSingle("Nightcall", by: [("Kavinsky", .main)])
        let album = makeAlbum("Outrun", by: "Kavinsky")

        album.append([track])
        try context.save()

        // Сам трек каскад сингла не задел: он уже числится за альбомом.
        #expect(albums.map(\.name) == ["Outrun"])
        #expect(((try? context.fetch(FetchDescriptor<Track>())) ?? []).count == 1)
        #expect(track.album?.persistentModelID == album.persistentModelID)
    }

    @Test func aRecordThatStillHasSongsStays() throws {
        let moving = makeSingle("Nightcall", by: [("Kavinsky", .main)], type: .EP)
        let ep = try #require(moving.album)
        let staying = Track(name: "Testarossa", album: ep, credits: [], genre: .pop, filename: "testarossa.mp3")
        staying.position = 1
        context.insert(staying)
        let album = makeAlbum("Outrun", by: "Kavinsky")

        album.append([moving])
        try context.save()

        #expect(Set(albums.map(\.name)) == ["Nightcall", "Outrun"])
        #expect(staying.position == 0)
        // Обложку и авторов отдаёт только сингл: у EP они общие для оставшихся песен.
        #expect(moving.credits.isEmpty)
    }
}
