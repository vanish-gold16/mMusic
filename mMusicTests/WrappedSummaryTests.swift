import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на свод за год: одна арифметическая ошибка здесь тихо портит весь
/// отчёт, а заметить её можно только сверив вручную всю историю.
@MainActor
struct WrappedSummaryTests {

    /// Контейнер хранится в самом наборе тестов: стоит его отпустить — модели
    /// становятся невалидными и обращение к ним роняет процесс.
    private let container: ModelContainer
    /// Свой календарь с UTC: месяцы и годы не должны зависеть от того, в каком
    /// поясе запускают тест.
    private let calendar: Calendar

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calendar = utc
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func makeTrack(_ name: String, filename: String? = nil, artists: [String] = [], genre: Genre = .pop) -> Track {
        let track = Track(name: name, credits: [], genre: genre, filename: filename ?? "\(name).mp3")
        container.mainContext.insert(track)

        for (position, artist) in artists.enumerated() {
            let artist = container.mainContext.findOrCreateArtist(named: artist)
            container.mainContext.insert(Credit(artist: artist, role: .main, position: position, track: track))
        }

        return track
    }

    @discardableResult
    private func play(_ track: Track, seconds: TimeInterval, on date: Date) -> PlayEvent {
        let event = PlayEvent(track: track, seconds: seconds)
        event.playedAt = date
        container.mainContext.insert(event)
        return event
    }

    private func summary(of events: [PlayEvent], year: Int) -> WrappedSummary {
        WrappedSummary.make(from: events, year: year, calendar: calendar)
    }

    @Test func countsOnlyTheChosenYear() {
        let track = makeTrack("Nightcall")
        let events = [
            play(track, seconds: 60, on: date(2026, 3, 4)),
            play(track, seconds: 60, on: date(2025, 3, 4))
        ]

        let year = summary(of: events, year: 2026)

        #expect(year.plays == 1)
        #expect(year.totalSeconds == 60)
    }

    /// Порядок топа — по времени: десять целых треков весомее двадцати
    /// брошенных на первой минуте.
    @Test func ranksByTimeNotByPlayCount() {
        let skipped = makeTrack("Skipped")
        let whole = makeTrack("Whole")

        var events = (0..<5).map { play(skipped, seconds: 30, on: date(2026, 2, 1 + $0)) }
        events.append(play(whole, seconds: 600, on: date(2026, 2, 10)))

        let top = summary(of: events, year: 2026).topTracks

        #expect(top.first?.name == "Whole")
        #expect(top.first?.count == 1)
        #expect(top.last?.name == "Skipped")
        #expect(top.last?.count == 5)
    }

    /// Одинаковые названия у разных песен — обычное дело, и слипаться в одну
    /// строку они не должны: ключ строки — имя файла.
    @Test func keepsSameNamedTracksApart() {
        let first = makeTrack("Intro", filename: "intro-a.mp3")
        let second = makeTrack("Intro", filename: "intro-b.mp3")

        let events = [
            play(first, seconds: 100, on: date(2026, 5, 1)),
            play(second, seconds: 50, on: date(2026, 5, 2))
        ]

        let top = summary(of: events, year: 2026).topTracks

        #expect(top.count == 2)
        #expect(top.allSatisfy { $0.name == "Intro" })
    }

    /// Фит — это тоже прослушивание артиста: секунды достаются каждому из них
    /// целиком, а не делятся между ними.
    @Test func givesEveryArtistTheWholePlay() {
        let track = makeTrack("Duet", artists: ["Vera Sound", "Mira"])
        let events = [play(track, seconds: 180, on: date(2026, 6, 6))]

        let artists = summary(of: events, year: 2026).topArtists

        #expect(artists.count == 2)
        #expect(artists.allSatisfy { $0.seconds == 180 })
    }

    @Test func spreadsSecondsOverMonthsAndNamesTheBusiest() {
        let track = makeTrack("Nightcall")
        let events = [
            play(track, seconds: 120, on: date(2026, 1, 5)),
            play(track, seconds: 600, on: date(2026, 9, 5)),
            play(track, seconds: 60, on: date(2026, 9, 6))
        ]

        let year = summary(of: events, year: 2026)

        #expect(year.monthlySeconds[0] == 120)
        #expect(year.monthlySeconds[8] == 660)
        #expect(year.monthlySeconds.filter { $0 > 0 }.count == 2)
        #expect(year.busiestMonth?.name == calendar.monthSymbols[8])
        #expect(year.busiestMonth?.seconds == 660)
    }

    /// Самый долгий месяц, а не самый частый: иначе «занятым» становился бы тот,
    /// в котором больше всего перещёлкивали очередь.
    @Test func busiestMonthGoesByTimeNotByPlays() {
        let track = makeTrack("Nightcall")
        var events = (0..<4).map { play(track, seconds: 40, on: date(2026, 4, 1 + $0)) }
        events.append(play(track, seconds: 900, on: date(2026, 11, 2)))

        #expect(summary(of: events, year: 2026).busiestMonth?.name == calendar.monthSymbols[10])
    }

    @Test func countsActiveDaysAndTheLongestStreak() {
        let track = makeTrack("Nightcall")
        // Три дня подряд, пропуск, потом два подряд.
        let days = [1, 2, 3, 7, 8]
        let events = days.map { play(track, seconds: 60, on: date(2026, 7, $0)) }
            + [play(track, seconds: 60, on: date(2026, 7, 2))] // второй раз в тот же день

        let year = summary(of: events, year: 2026)

        #expect(year.activeDays == 5)
        #expect(year.longestStreak == 3)
    }

    @Test func countsHowMuchDifferentMusicThereWas() {
        let events = [
            play(makeTrack("One", artists: ["Vera Sound"]), seconds: 60, on: date(2026, 2, 1)),
            play(makeTrack("Two", artists: ["Vera Sound"]), seconds: 60, on: date(2026, 2, 2)),
            play(makeTrack("Three", artists: ["Mira"]), seconds: 60, on: date(2026, 2, 3))
        ]

        let year = summary(of: events, year: 2026)

        #expect(year.distinctTracks == 3)
        #expect(year.distinctArtists == 2)
    }

    @Test func emptyYearSaysSoInsteadOfCrashing() {
        let year = summary(of: [], year: 2026)

        #expect(year.plays == 0)
        #expect(year.busiestMonth == nil)
        #expect(year.longestStreak == 0)
        #expect(year.monthlySeconds.count == 12)
        #expect(year.topTracks.isEmpty)
    }

    @Test func listsYearsNewestFirst() {
        let track = makeTrack("Nightcall")
        let events = [
            play(track, seconds: 60, on: date(2024, 1, 1)),
            play(track, seconds: 60, on: date(2026, 1, 1)),
            play(track, seconds: 60, on: date(2026, 2, 1))
        ]

        #expect(WrappedSummary.years(in: events, calendar: calendar) == [2026, 2024])
    }

    /// Полминуты — это уже засчитанное прослушивание, и «0 min» о нём соврало бы.
    @Test func roundsShortEntriesUpToAMinute() {
        let track = makeTrack("Short")
        let events = [play(track, seconds: 31, on: date(2026, 1, 1))]

        #expect(summary(of: events, year: 2026).topTracks.first?.minutes == 1)
    }

    /// Дни считаются от 1 января, и в високосном году их на один больше:
    /// иначе 31 декабря падало бы за край дорожки.
    @Test func spreadsSecondsOverTheDaysOfTheYear() {
        let track = makeTrack("Nightcall")
        let events = [
            play(track, seconds: 60, on: date(2024, 1, 1)),
            play(track, seconds: 30, on: date(2024, 1, 1)),
            play(track, seconds: 120, on: date(2024, 2, 1)),
            play(track, seconds: 240, on: date(2024, 12, 31))
        ]

        let leap = summary(of: events, year: 2024)

        #expect(leap.dailySeconds.count == 366)
        #expect(leap.dailySeconds[0] == 90)
        #expect(leap.dailySeconds[31] == 120)
        #expect(leap.dailySeconds[365] == 240)
        #expect(summary(of: [], year: 2025).dailySeconds.count == 365)
    }
}
