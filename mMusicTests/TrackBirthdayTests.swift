import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на годовщины треков: чистые даты и арифметика, зато ошибиться в них
/// легко, а увидеть ошибку — только через год.
@MainActor
struct TrackBirthdayTests {

    /// Контейнер хранится в самом наборе тестов: стоит его отпустить — модели
    /// становятся невалидными и обращение к ним роняет процесс.
    private let container: ModelContainer

    /// Свой календарь с UTC: тест не должен зависеть от того, в каком поясе
    /// его запускают.
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

    private func makeTrack(_ name: String, addedAt: Date, plays: Int = 0) -> Track {
        let track = Track(name: name, credits: [], genre: .pop, filename: "\(name).mp3")
        track.addedAt = addedAt
        track.playCount = plays
        container.mainContext.insert(track)
        return track
    }

    @Test func celebratesExactlyOneYearLater() {
        let track = makeTrack("Nightcall", addedAt: date(2025, 8, 23))

        let birthdays = TrackBirthday.today(
            in: [track],
            listened: [:],
            on: date(2026, 8, 23),
            calendar: calendar
        )

        #expect(birthdays.count == 1)
        #expect(birthdays.first?.years == 1)
    }

    @Test func tracksAddedTodayAreNotCelebrated() {
        let track = makeTrack("Fresh", addedAt: date(2026, 8, 23))

        let birthdays = TrackBirthday.today(
            in: [track],
            listened: [:],
            on: date(2026, 8, 23),
            calendar: calendar
        )

        #expect(birthdays.isEmpty)
    }

    @Test func otherDaysAreQuiet() {
        let track = makeTrack("Nightcall", addedAt: date(2025, 8, 23))

        let birthdays = TrackBirthday.today(
            in: [track],
            listened: [:],
            on: date(2026, 8, 24),
            calendar: calendar
        )

        #expect(birthdays.isEmpty)
    }

    /// Трек, добавленный 29 февраля, в невисокосный год празднует 1 марта —
    /// иначе у него был бы день рождения раз в четыре года.
    @Test func leapDayTrackCelebratesOnMarchFirst() {
        let track = makeTrack("Leap", addedAt: date(2024, 2, 29))

        let onMarchFirst = TrackBirthday.today(
            in: [track],
            listened: [:],
            on: date(2027, 3, 1),
            calendar: calendar
        )
        let onFebruaryLast = TrackBirthday.today(
            in: [track],
            listened: [:],
            on: date(2027, 2, 28),
            calendar: calendar
        )

        #expect(onMarchFirst.count == 1)
        #expect(onFebruaryLast.isEmpty)
    }

    @Test func mostPlayedGoesFirst() {
        let quiet = makeTrack("Quiet", addedAt: date(2025, 8, 23), plays: 2)
        let loud = makeTrack("Loud", addedAt: date(2024, 8, 23), plays: 40)

        let birthdays = TrackBirthday.today(
            in: [quiet, loud],
            listened: [:],
            on: date(2026, 8, 23),
            calendar: calendar
        )

        #expect(birthdays.map(\.track.name) == ["Loud", "Quiet"])
        #expect(birthdays.first?.years == 2)
    }

    @Test func summaryUsesHistorySeconds() {
        let track = makeTrack("Nightcall", addedAt: date(2025, 8, 23), plays: 47)

        let birthdays = TrackBirthday.today(
            in: [track],
            listened: ["Nightcall.mp3": 11_520],
            on: date(2026, 8, 23),
            calendar: calendar
        )

        #expect(birthdays.first?.listeningTime == "3 h 12 min")
        #expect(birthdays.first?.summary == "47 plays • 3 h 12 min")
    }

    @Test func upcomingIsSortedByDateAndLimited() {
        let september = makeTrack("September", addedAt: date(2024, 9, 1))
        let october = makeTrack("October", addedAt: date(2024, 10, 1))
        let july = makeTrack("July", addedAt: date(2024, 7, 1))

        let upcoming = TrackBirthday.upcoming(
            in: [october, july, september],
            listened: [:],
            from: date(2026, 8, 23),
            calendar: calendar,
            limit: 2
        )

        // Июльская годовщина в этом году уже прошла — она уезжает на следующий год
        // и в двойку ближайших не попадает.
        #expect(upcoming.map(\.name) == ["September", "October"])
        #expect(upcoming.first?.years == 2)
    }

    @Test func listenedSumsHistoryByFile() {
        let track = makeTrack("Nightcall", addedAt: date(2025, 8, 23))
        container.mainContext.insert(PlayEvent(track: track, seconds: 120))
        container.mainContext.insert(PlayEvent(track: track, seconds: 60))

        let listened = TrackBirthday.listened(in: container.mainContext)

        #expect(listened["Nightcall.mp3"] == 180)
    }
}
