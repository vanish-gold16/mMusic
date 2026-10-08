import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на авторов трека из библиотеки в форме нового альбома: редактор
/// начинает с того, что у трека есть, а сохранение пишет то, что в редакторе.
/// Ошибка здесь тихая — пропавший гость или автор, задвоенный на странице артиста.
@MainActor
struct TrackArtistDraftsTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    private func makeSingle(by artists: [(String, CreditRole)]) -> Track {
        let album = Album(name: "Nightcall", type: .single)
        context.insert(album)
        let track = Track(name: "Nightcall", album: album, credits: [], genre: .pop, filename: "nightcall.mp3")
        context.insert(track)

        for (position, (name, role)) in artists.enumerated() {
            context.insert(Credit(artist: context.findOrCreateArtist(named: name), role: role, position: position, album: album))
        }
        return track
    }

    private func roles(_ drafts: [ArtistDraft]) -> [String] {
        drafts.map { "\($0.name):\($0.role.rawValue)" }
    }

    @Test func draftsKeepRolesAlbumArtistsFirst() {
        let track = makeSingle(by: [("Kavinsky", .main), ("Lovefoxxx", .featured)])
        context.insert(Credit(artist: context.findOrCreateArtist(named: "Guest"), role: .featured, position: 0, track: track))

        #expect(roles(track.artistDrafts) == ["Kavinsky:main", "Lovefoxxx:featured", "Guest:featured"])
    }

    @Test func draftsDoNotRepeatAName() {
        let track = makeSingle(by: [("Kavinsky", .main)])
        context.insert(Credit(artist: context.findOrCreateArtist(named: "Kavinsky"), role: .featured, position: 0, track: track))

        #expect(roles(track.artistDrafts) == ["Kavinsky:main"])
    }

    @Test func ownArtistsAreRewrittenWithoutAlbumArtists() throws {
        let track = makeSingle(by: [("Kavinsky", .main)])
        context.insert(Credit(artist: context.findOrCreateArtist(named: "Old guest"), role: .featured, position: 0, track: track))

        track.setOwnArtists(
            [ArtistDraft(name: "kavinsky"), ArtistDraft(name: "Lovefoxxx", role: .featured), ArtistDraft(name: "Sebastian")],
            albumArtists: ["Kavinsky"],
            in: context
        )
        // Удалённые отметки уходят из `credits` на сохранении.
        try context.save()

        let own = track.credits.sorted { $0.position < $1.position }
        #expect(own.map(\.artist.name) == ["Lovefoxxx", "Sebastian"])
        #expect(own.map(\.role) == [.featured, .main])
        #expect(own.map(\.position) == [0, 1])
    }

    /// Нетронутый список трека с сингла, записанный после переезда, даёт то же,
    /// что и сам переезд: автор альбома унаследован, гость сингла — за треком.
    @Test func anUntouchedListMatchesTheMove() throws {
        let track = makeSingle(by: [("Kavinsky", .main), ("Lovefoxxx", .featured)])
        let drafts = track.artistDrafts

        let album = Album(name: "Outrun", type: .LP)
        context.insert(album)
        context.insert(Credit(artist: context.findOrCreateArtist(named: "Kavinsky"), position: 0, album: album))
        album.append([track])
        track.setOwnArtists(drafts, albumArtists: ["Kavinsky"], in: context)
        try context.save()

        #expect(track.artistNames == ["Kavinsky", "Lovefoxxx"])
        #expect(track.credits.map(\.role) == [.featured])
    }
}
