import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на автоподборки: слепок и паспорт. Слепок пишет в базу, и ошибка
/// в нём — это плейлист с перепутанным порядком, который пользователь оставит себе.
@MainActor
struct SmartPlaylistTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeTrack(_ name: String, plays: Int = 0, duration: TimeInterval = 0) -> Track {
        let track = Track(name: name, credits: [], genre: .pop, filename: "\(name).mp3")
        track.playCount = plays
        track.duration = duration
        container.mainContext.insert(track)
        return track
    }

    /// Слепок хранит подборку в её порядке и с месяцем в имени.
    @Test func keepingFreezesTheOrderAndDatesTheName() {
        let tracks = [makeTrack("Low", plays: 1), makeTrack("High", plays: 9), makeTrack("Mid", plays: 4)]
        let mostPlayed = SmartPlaylist.mostPlayed.tracks(from: tracks)

        let kept = SmartPlaylist.mostPlayed.keep(mostPlayed, in: container.mainContext)

        #expect(kept.orderedTracks.map(\.name) == ["High", "Mid", "Low"])
        #expect(kept.name.hasPrefix("Most played, "))
        #expect(kept.name.hasSuffix(String(Calendar.current.component(.year, from: .now))))
    }

    @Test func summaryCountsTracksAndMinutes() {
        let tracks = [makeTrack("One", duration: 1800), makeTrack("Two", duration: 2400)]

        #expect(tracks.summary(includingArtists: false) == "2 TRACKS  ·  1 H 10 MIN")
        #expect([Track]().summary(includingArtists: false) == "NO TRACKS YET")
    }

    /// Трек хоть в одном плейлисте — разложен; в подборке остаются только
    /// те, что ещё нигде не лежат, свежие сверху.
    @Test func notInPlaylistsKeepsOnlyUnfiledTracks() {
        let filed = makeTrack("Filed")
        let older = makeTrack("Older")
        older.addedAt = .now.addingTimeInterval(-3600)
        let newer = makeTrack("Newer")

        let playlist = Playlist(name: "Night drives", items: [])
        container.mainContext.insert(playlist)
        container.mainContext.insert(TrackPlaylistItem(track: filed, playlist: playlist, position: 0))

        let unfiled = SmartPlaylist.notInPlaylists.tracks(from: [filed, older, newer])

        #expect(unfiled.map(\.name) == ["Newer", "Older"])
    }
}
