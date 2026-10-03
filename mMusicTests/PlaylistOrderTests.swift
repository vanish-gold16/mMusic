import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Порядок плейлистов в библиотеке: закреплённые сверху, и внутри каждой группы —
/// по свежести запуска. Закреплённые тоже перестраиваются между собой, а не
/// стоят навсегда в том порядке, в каком их закрепили.
@MainActor
struct PlaylistOrderTests {

    /// Контейнер хранится в самом наборе тестов: стоит его отпустить — модели
    /// становятся невалидными и обращение к ним роняет процесс.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makePlaylist(_ name: String, pinned: Bool = false, playedMinutesAgo: Double? = nil) -> Playlist {
        let playlist = Playlist(name: name, items: [], isPinned: pinned)
        if let playedMinutesAgo {
            playlist.lastPlayedAt = Date.now.addingTimeInterval(-playedMinutesAgo * 60)
        }
        container.mainContext.insert(playlist)
        return playlist
    }

    @Test func pinnedComeFirstEvenIfPlayedLongAgo() {
        let fresh = makePlaylist("Fresh", playedMinutesAgo: 1)
        let pinned = makePlaylist("Pinned", pinned: true, playedMinutesAgo: 10_000)

        #expect([fresh, pinned].byLastPlayed.map(\.name) == ["Pinned", "Fresh"])
    }

    @Test func pinnedAreOrderedByLastPlayedAmongThemselves() {
        let gym = makePlaylist("Gym", pinned: true, playedMinutesAgo: 300)
        let night = makePlaylist("Night", pinned: true, playedMinutesAgo: 5)
        let morning = makePlaylist("Morning", pinned: true)
        let other = makePlaylist("Other", playedMinutesAgo: 1)

        #expect([gym, night, morning, other].byLastPlayed.map(\.name) == ["Night", "Gym", "Morning", "Other"])
    }

    @Test func playingAPinnedPlaylistMovesItToTheTopOfThePinned() {
        let gym = makePlaylist("Gym", pinned: true, playedMinutesAgo: 5)
        let night = makePlaylist("Night", pinned: true, playedMinutesAgo: 300)
        let other = makePlaylist("Other", playedMinutesAgo: 1)

        night.markPlayed()

        #expect([gym, night, other].byLastPlayed.map(\.name) == ["Night", "Gym", "Other"])
    }

    @Test func neverPlayedFallBackToName() {
        let beta = makePlaylist("beta", pinned: true)
        let alpha = makePlaylist("Alpha", pinned: true)

        #expect([beta, alpha].byLastPlayed.map(\.name) == ["Alpha", "beta"])
    }
}
