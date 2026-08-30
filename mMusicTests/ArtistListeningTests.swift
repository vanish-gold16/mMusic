import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на «время с артистом»: событие ищет своего артиста двумя путями сразу,
/// и легко получить как потерянные минуты, так и посчитанные дважды.
@MainActor
struct ArtistListeningTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeTrack(_ name: String, artists: [String] = []) -> Track {
        let track = Track(name: name, credits: [], genre: .pop, filename: "\(name).mp3")
        container.mainContext.insert(track)

        for (position, name) in artists.enumerated() {
            let artist = container.mainContext.findOrCreateArtist(named: name)
            container.mainContext.insert(Credit(artist: artist, role: .main, position: position, track: track))
        }

        return track
    }

    private func play(_ track: Track, seconds: TimeInterval, daysAgo: Int = 0) -> PlayEvent {
        let event = PlayEvent(track: track, seconds: seconds)
        event.playedAt = .now.addingTimeInterval(-86_400 * Double(daysAgo))
        container.mainContext.insert(event)
        return event
    }

    @Test func addsUpEventsThatNameTheArtist() {
        let track = makeTrack("Nightcall", artists: ["Vera Sound"])
        let events = [play(track, seconds: 120), play(track, seconds: 60)]

        let listening = ArtistListening.make(for: "Vera Sound", filenames: [], from: events)

        #expect(listening.seconds == 180)
        #expect(listening.plays == 2)
    }

    /// Артиста могли вписать в авторы уже после прослушиваний — в старых событиях
    /// его имени нет, зато есть имя файла.
    @Test func alsoCountsEventsRecordedBeforeTheCreditAppeared() {
        let track = makeTrack("Nightcall")
        let events = [play(track, seconds: 200)]

        let listening = ArtistListening.make(
            for: "Vera Sound",
            filenames: ["Nightcall.mp3"],
            from: events
        )

        #expect(listening.seconds == 200)
        #expect(listening.plays == 1)
    }

    /// Событие, подошедшее сразу по двум признакам, — всё то же одно событие.
    @Test func countsMatchingEventOnlyOnce() {
        let track = makeTrack("Nightcall", artists: ["Vera Sound"])
        let events = [play(track, seconds: 90)]

        let listening = ArtistListening.make(
            for: "Vera Sound",
            filenames: ["Nightcall.mp3"],
            from: events
        )

        #expect(listening.seconds == 90)
        #expect(listening.plays == 1)
    }

    @Test func ignoresOtherArtists() {
        let mine = makeTrack("Nightcall", artists: ["Vera Sound"])
        let other = makeTrack("Elsewhere", artists: ["Mira"])
        let events = [play(mine, seconds: 90), play(other, seconds: 300)]

        #expect(ArtistListening.make(for: "Vera Sound", filenames: [], from: events).seconds == 90)
    }

    @Test func remembersTheFirstMeeting() {
        let track = makeTrack("Nightcall", artists: ["Vera Sound"])
        let recent = play(track, seconds: 60, daysAgo: 1)
        let oldest = play(track, seconds: 60, daysAgo: 400)

        let listening = ArtistListening.make(for: "Vera Sound", filenames: [], from: [recent, oldest])

        #expect(listening.firstPlayedAt == oldest.playedAt)
    }

    @Test func neverRoundsAStartedPlayDownToZero() {
        let track = makeTrack("Nightcall", artists: ["Vera Sound"])
        let events = [play(track, seconds: 31)]

        let listening = ArtistListening.make(for: "Vera Sound", filenames: [], from: events)

        #expect(listening.minutes == 1)
        #expect(listening.hoursAndMinutes == nil)
    }

    @Test func spellsOutHoursOnceThereAreAny() {
        let track = makeTrack("Nightcall", artists: ["Vera Sound"])
        let events = [play(track, seconds: 3660)]

        let listening = ArtistListening.make(for: "Vera Sound", filenames: [], from: events)

        #expect(listening.minutes == 61)
        #expect(listening.hoursAndMinutes == "1 h 1 min")
    }

    @Test func staysSilentWhenNothingWasPlayed() {
        let listening = ArtistListening.make(for: "Vera Sound", filenames: [], from: [])

        #expect(listening.plays == 0)
        #expect(listening.minutes == 0)
        #expect(listening.firstPlayedAt == nil)
    }
}
