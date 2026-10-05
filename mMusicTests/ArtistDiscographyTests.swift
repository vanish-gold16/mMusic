import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на полки страницы артиста: какая пластинка его, а где он в гостях.
/// Ошибка здесь не падает, а тихо кладёт чужой альбом в «его альбомы»
/// или теряет гостевой трек.
@MainActor
struct ArtistDiscographyTests {

    private let container: ModelContainer
    private let artist: Artist

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        artist = container.mainContext.findOrCreateArtist(named: "Vera Sound")
    }

    private var context: ModelContext { container.mainContext }

    private func makeAlbum(
        _ name: String,
        type: Album.AlbumType = .LP,
        tracks trackCount: Int = 3,
        released year: Int? = nil
    ) -> Album {
        let album = Album(name: name, type: type)
        if let year {
            album.release = Calendar.current.date(from: DateComponents(year: year, month: 6, day: 1))
        }
        context.insert(album)

        for index in 0..<trackCount {
            let track = Track(name: "\(name) \(index + 1)", credits: [], genre: .pop, filename: "\(name)-\(index).mp3")
            track.position = index
            track.album = album
            context.insert(track)
        }

        return album
    }

    private func credit(_ artist: Artist, on album: Album, as role: CreditRole = .main, position: Int = 0) {
        context.insert(Credit(artist: artist, role: role, position: position, album: album))
    }

    private func credit(_ artist: Artist, on track: Track, as role: CreditRole = .featured) {
        context.insert(Credit(artist: artist, role: role, position: 0, track: track))
    }

    private func names(_ albums: [Album]) -> [String] {
        albums.map(\.name)
    }

    private func sortedTracks(of album: Album) -> [Track] {
        album.tracks.sorted { $0.position < $1.position }
    }

    @Test func ownRecordsAreSplitByFormat() {
        let lp = makeAlbum("Outrun", type: .LP)
        let ep = makeAlbum("Midnight", type: .EP)
        let single = makeAlbum("Nightcall", type: .single, tracks: 1)
        [lp, ep, single].forEach { credit(artist, on: $0) }

        let discography = ArtistDiscography(artist: artist)

        #expect(names(discography.albums) == ["Outrun"])
        #expect(Set(names(discography.singles)) == ["Midnight", "Nightcall"])
        #expect(discography.featuredOn.isEmpty)
    }

    /// Без звезды в авторах альбома — гость на всём альбоме.
    @Test func albumCreditWithoutTheStarIsAGuestSpot() {
        let host = context.findOrCreateArtist(named: "Host")
        let album = makeAlbum("Utopia")
        credit(host, on: album)
        credit(artist, on: album, as: .featured, position: 1)

        let discography = ArtistDiscography(artist: artist)

        #expect(discography.albums.isEmpty)
        #expect(names(discography.featuredOn) == ["Utopia"])
        #expect(discography.guestTracks(on: album).map(\.name) == sortedTracks(of: album).map(\.name))
    }

    /// Отметка на одном треке чужого альбома кладёт альбом в гостевые,
    /// и светиться на нём должен только этот трек.
    @Test func trackCreditOnSomeoneElsesAlbumIsAGuestSpot() {
        let host = context.findOrCreateArtist(named: "Host")
        let album = makeAlbum("Utopia", tracks: 4)
        credit(host, on: album)
        let guestTrack = sortedTracks(of: album)[2]
        credit(artist, on: guestTrack)

        let discography = ArtistDiscography(artist: artist)

        #expect(names(discography.featuredOn) == ["Utopia"])
        #expect(discography.guestTracks(on: album).map(\.name) == [guestTrack.name])
    }

    /// Звезда на треке чужого альбома альбом своим не делает.
    @Test func mainCreditOnASingleTrackKeepsTheAlbumSomeoneElses() {
        let host = context.findOrCreateArtist(named: "Host")
        let album = makeAlbum("Split")
        credit(host, on: album)
        credit(artist, on: sortedTracks(of: album)[0], as: .main)

        let discography = ArtistDiscography(artist: artist)

        #expect(discography.albums.isEmpty)
        #expect(names(discography.featuredOn) == ["Split"])
    }

    /// Отметка на треке своего альбома ничего не меняет: альбом остаётся
    /// среди его альбомов и не всплывает ещё раз в гостевых.
    @Test func trackCreditOnOwnAlbumDoesNotMakeItAGuestSpot() {
        let album = makeAlbum("Outrun")
        credit(artist, on: album)
        credit(artist, on: sortedTracks(of: album)[1])

        let discography = ArtistDiscography(artist: artist)

        #expect(names(discography.albums) == ["Outrun"])
        #expect(discography.featuredOn.isEmpty)
    }

    /// Записан в авторы альбома дважды — основным и гостем: альбом его.
    @Test func starWinsOverGuestOnTheSameAlbum() {
        let album = makeAlbum("Outrun")
        credit(artist, on: album, as: .featured, position: 0)
        credit(artist, on: album, as: .main, position: 1)

        let discography = ArtistDiscography(artist: artist)

        #expect(names(discography.albums) == ["Outrun"])
        #expect(discography.featuredOn.isEmpty)
    }

    /// По дате выхода от старых к новым, без даты — в конце.
    @Test func shelvesRunOldestFirst() {
        let undated = makeAlbum("Undated")
        let new = makeAlbum("New", released: 2024)
        let old = makeAlbum("Old", released: 2012)
        [undated, new, old].forEach { credit(artist, on: $0) }

        let discography = ArtistDiscography(artist: artist)

        #expect(names(discography.albums) == ["Old", "New", "Undated"])
    }

    /// Кольца пластинки артиста — его пластинки от первой к последней;
    /// гостевые туда не попадают, пока есть свои.
    @Test func careerRunsOldestFirstAndSkipsGuestSpots() {
        let host = context.findOrCreateArtist(named: "Host")
        let guest = makeAlbum("Guest", released: 2018)
        credit(host, on: guest)
        credit(artist, on: sortedTracks(of: guest)[0])

        let single = makeAlbum("Single", type: .single, tracks: 1, released: 2020)
        let lp = makeAlbum("Debut", released: 2015)
        [single, lp].forEach { credit(artist, on: $0) }

        #expect(names(ArtistDiscography(artist: artist).career) == ["Debut", "Single"])
    }

    /// Только гостевое — тогда кольца из него: пустой диск ничего бы не сказал.
    @Test func careerFallsBackToGuestSpots() {
        let host = context.findOrCreateArtist(named: "Host")
        let album = makeAlbum("Utopia")
        credit(host, on: album)
        credit(artist, on: sortedTracks(of: album)[0])

        #expect(names(ArtistDiscography(artist: artist).career) == ["Utopia"])
    }
}
