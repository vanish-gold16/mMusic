import Foundation
import Testing
@testable import mMusic

/// Тесты радара релизов: как он узнаёт артиста в каталоге и что считает новостью.
/// Ошибки здесь видно не сразу — либо уведомление о старом альбоме, либо
/// молчание о новом, — поэтому всё, что решает, проверено без сети.
struct ReleaseRadarTests {

    /// Свой календарь в UTC: тест не должен зависеть от пояса, где его запускают.
    private let calendar: Calendar = {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func artist(_ name: String, titles: [String] = [], owned: [String] = []) -> LibraryArtist {
        LibraryArtist(
            key: RadarText.key(name),
            name: name,
            titleKeys: titles.reduce(into: Set<String>()) { $0.formUnion(RadarText.titleKeys($1)) },
            ownedKeys: Set(owned.map(RadarText.releaseKey)),
            searchTitles: titles,
            weight: 1
        )
    }

    private func release(
        _ id: Int,
        _ title: String,
        day: String,
        source: RadarRelease.Source = .deezer,
        isFeature: Bool = false
    ) -> RadarRelease {
        RadarRelease(
            source: source, sourceID: id, title: title, kind: .single, releaseDay: day,
            cover: nil, link: nil, byline: "someone", isFeature: isFeature
        )
    }

    // MARK: - Имена и названия

    @Test func decomposedLettersMatchComposed() {
        // Так «тёмный принц» лежит в базе: имя пришло из имени файла.
        let decomposed = "те\u{0308}мный принц"
        let composed = "тёмный принц"

        // Для Swift это одна строка — `==` сравнивает буквы, а не байты.
        // Но в адрес запроса уходят байты, и их разное число.
        #expect(Array(decomposed.unicodeScalars) != Array(composed.unicodeScalars))
        #expect(Array(RadarText.query(decomposed).unicodeScalars) == Array(composed.unicodeScalars))
        #expect(RadarText.key(decomposed) == RadarText.key(composed))
    }

    @Test func spellingsOfOneArtistShareAKey() {
        #expect(RadarText.key("Limp Bizkit") == RadarText.key("LimpBizkit"))
        #expect(RadarText.key("КИНО") == RadarText.key("Кино"))
        #expect(RadarText.key("AVA MAX") == RadarText.key("Ava Max"))
        #expect(RadarText.key("тёмный принц") == RadarText.key("темный принц"))
        #expect(RadarText.key("Lover") != RadarText.key("Lovers"))
    }

    @Test func dirtyTitlesYieldTheSong() {
        #expect(RadarText.titleKeys("Everybody Wants To Rule The World (Official Music Video)")
            .contains(RadarText.key("Everybody Wants To Rule The World")))
        #expect(RadarText.titleKeys("Clarity x Better Off Alone").contains(RadarText.key("Better Off Alone")))
        #expect(RadarText.titleKeys("Krewella - Alive (Remix)").contains(RadarText.key("Alive")))
        #expect(RadarText.titleKeys("L.E.S. best part + slowed reverb").contains(RadarText.key("L.E.S. best part")))
        #expect(RadarText.titleKeys("Roar - Single").contains(RadarText.key("Roar")))
    }

    @Test func genericTitlesProveNothing() {
        #expect(RadarText.titleKeys("Intro").isEmpty)
        #expect(!RadarText.titleKeys("hold up - Single").contains("single"))
    }

    @Test func remixIsAnotherRelease() {
        #expect(RadarText.releaseKey("Loser (Fcukers Remix)") != RadarText.releaseKey("Loser"))
        #expect(RadarText.releaseKey("hold up - Single") == RadarText.releaseKey("hold up"))
    }

    // MARK: - Опознание

    private func candidate(_ id: Int, _ name: String, fans: Int = 0, titles: [String] = []) -> RadarLogic.Candidate {
        RadarLogic.Candidate(
            id: id, name: name, picture: nil, fans: fans,
            titleKeys: titles.reduce(into: Set<String>()) { $0.formUnion(RadarText.titleKeys($1)) }
        )
    }

    @Test func namesakeWithOurSongsWins() {
        let library = artist("Lover", titles: ["Sunday Light"])
        let match = RadarLogic.match(library, among: [
            candidate(1, "Lover", fans: 50_000, titles: ["Other Song"]),
            candidate(2, "LOVER", fans: 90, titles: ["Sunday Light (Remastered)"])
        ])

        #expect(match.id == 2)
        #expect(match.status == .confirmed)
    }

    @Test func differentNameNeverMatches() {
        let match = RadarLogic.match(artist("Lover", titles: ["Sunday Light"]), among: [
            candidate(1, "Lovers", titles: ["Sunday Light"])
        ])

        #expect(match.status == .missing)
        #expect(match.id == nil)
    }

    @Test func onlyNamesakeIsProbable() {
        let match = RadarLogic.match(artist("Katy Perry", titles: ["Sonic Blaster x Last Friday Night"]), among: [
            candidate(7, "Katy Perry", fans: 9_000_000, titles: ["Roar"])
        ])

        #expect(match.id == 7)
        #expect(match.status == .probable)
        // Только по имени — радар за ним сам не следит, ждёт подтверждения.
        #expect(!match.isWatched)

        var entry = RadarArtist(name: "Katy Perry")
        entry.deezer = match
        #expect(entry.needsReview)
        entry.apple = RadarMatch(id: 3, name: "Katy Perry", status: .confirmed, decidedAt: .now)
        #expect(!entry.needsReview)
    }

    @Test func farMoreKnownNamesakeIsProbable() {
        let match = RadarLogic.match(artist("David Guetta"), among: [
            candidate(1, "David Guetta", fans: 8_000_000),
            candidate(2, "David Guetta", fans: 1_200)
        ])

        #expect(match.id == 1)
        #expect(match.status == .probable)
    }

    @Test func equalNamesakesStayUnknown() {
        let match = RadarLogic.match(artist("wo"), among: [
            candidate(1, "wo", fans: 30),
            candidate(2, "WO", fans: 12)
        ])

        #expect(match.status == .missing)
    }

    // MARK: - Что считать новым

    @Test func firstLookIsSilent() {
        let now = date(2026, 10, 8)
        let outcome = RadarLogic.merge(
            [release(1, "Fresh", day: "2026-10-03"), release(2, "Old", day: "2025-01-10")],
            for: artist("madk1d"), known: nil, into: [], now: now, calendar: calendar
        )

        #expect(outcome.known == [1, 2])
        #expect(outcome.outNow.isEmpty)
        // Свежее — на полку, но молча и днём своего выхода.
        #expect(outcome.releases.map(\.id) == ["deezer:1"])
        #expect(outcome.releases[0].isQuiet)
        #expect(outcome.releases[0].arrivesAt == date(2026, 10, 3, hour: 0))
    }

    @Test func firstLookStillAnnouncesUpcoming() {
        let now = date(2026, 10, 8)
        let outcome = RadarLogic.merge(
            [release(1, "Soon", day: "2026-10-10")],
            for: artist("madk1d"), known: nil, into: [], now: now, calendar: calendar
        )

        #expect(outcome.upcoming.map(\.id) == ["deezer:1"])
        #expect(!outcome.releases[0].isQuiet)
        #expect(outcome.releases[0].arrivesAt == date(2026, 10, 10, hour: 0))
    }

    @Test func newReleaseIsReportedOnce() {
        let now = date(2026, 10, 10)
        let first = RadarLogic.merge(
            [release(1, "Old", day: "2026-09-01"), release(3, "Dropped", day: "2026-10-10")],
            for: artist("madk1d"), known: [1], into: [], now: now, calendar: calendar
        )

        #expect(first.outNow.map(\.id) == ["deezer:3"])
        #expect(first.releases[0].arrivesAt == now)

        let second = RadarLogic.merge(
            [release(1, "Old", day: "2026-09-01"), release(3, "Dropped", day: "2026-10-10")],
            for: artist("madk1d"), known: first.known, into: first.releases, now: now, calendar: calendar
        )
        #expect(second.outNow.isEmpty)
        #expect(second.releases.count == 1)
    }

    @Test func backCatalogUploadIsNotNews() {
        let outcome = RadarLogic.merge(
            [release(9, "Reissue of an old album", day: "2019-05-01")],
            for: artist("Кино"), known: [1], into: [], now: date(2026, 10, 8), calendar: calendar
        )

        #expect(outcome.known.contains(9))
        #expect(outcome.releases.isEmpty)
    }

    @Test func whatIsInTheLibraryIsNotNews() {
        let outcome = RadarLogic.merge(
            [release(4, "hold up - Single", day: "2026-10-08")],
            for: artist("FORTUNA 812", owned: ["hold up"]), known: [], into: [], now: date(2026, 10, 8), calendar: calendar
        )

        #expect(outcome.releases.isEmpty)
        #expect(outcome.outNow.isEmpty)
    }

    @Test func sharedReleaseNamesBothArtists() {
        let now = date(2026, 10, 8)
        let villian = RadarLogic.merge(
            [release(5, "Красивое Зло", day: "2026-10-08")],
            for: artist("VILLIAN"), known: [], into: [], now: now, calendar: calendar
        )
        // Тот же альбом у Apple у второго артиста — фит, и дата на день другая.
        let madkid = RadarLogic.merge(
            [release(77, "Красивое Зло", day: "2026-10-07", source: .apple, isFeature: true)],
            for: artist("madk1d"), known: [], into: villian.releases, now: now, calendar: calendar
        )

        #expect(madkid.releases.count == 1)
        #expect(madkid.releases[0].libraryArtists == ["VILLIAN", "madk1d"])
        // Свой релиз хоть у одного — значит, не фит.
        #expect(!madkid.releases[0].isFeature)
        #expect(madkid.outNow.isEmpty)
        #expect(madkid.known == [77])
    }

    @Test func appleFeatTitleIsTheSameSingle() {
        let now = date(2026, 10, 8)
        let deezer = RadarLogic.merge(
            [release(1, "Мало 2.0", day: "2026-10-08")],
            for: artist("Егор Крид"), known: [], into: [], now: now, calendar: calendar
        )
        let apple = RadarLogic.merge(
            [release(2, "Мало 2.0 (feat. madk1d) - Single", day: "2026-10-08", source: .apple, isFeature: true)],
            for: artist("madk1d"), known: [], into: deezer.releases, now: now, calendar: calendar
        )

        #expect(apple.releases.count == 1)
        #expect(apple.releases[0].libraryArtists == ["Егор Крид", "madk1d"])
    }

    @Test func sameDayRemixStaysSeparate() {
        let outcome = RadarLogic.merge(
            [release(1, "Loser", day: "2026-10-08"), release(2, "Loser (Fcukers Remix)", day: "2026-10-08")],
            for: artist("Tame Impala"), known: [], into: [], now: date(2026, 10, 8), calendar: calendar
        )

        #expect(outcome.releases.count == 2)
        #expect(outcome.outNow.count == 2)
    }

    @Test func postponedAnnouncementMoves() {
        let now = date(2026, 10, 8)
        let announced = RadarLogic.merge(
            [release(6, "Album", day: "2026-10-10")],
            for: artist("Tame Impala"), known: [], into: [], now: now, calendar: calendar
        )
        let moved = RadarLogic.merge(
            [release(6, "Album", day: "2026-10-17")],
            for: artist("Tame Impala"), known: announced.known, into: announced.releases, now: now, calendar: calendar
        )

        #expect(moved.releases[0].releaseDay == "2026-10-17")
        #expect(moved.releases[0].arrivesAt == date(2026, 10, 17, hour: 0))
        #expect(moved.upcoming.count == 1)
    }

    @Test func announcementPicksUpItsLateCover() {
        let now = date(2026, 10, 8)
        let announced = RadarLogic.merge(
            [release(8, "Album", day: "2026-10-16")],
            for: artist("Galantis"), known: [], into: [], now: now, calendar: calendar
        )
        #expect(announced.releases[0].cover == nil)

        var withCover = release(8, "Album", day: "2026-10-16")
        withCover.cover = URL(string: "https://example.com/cover.jpg")
        let later = RadarLogic.merge(
            [withCover],
            for: artist("Galantis"), known: announced.known, into: announced.releases, now: now, calendar: calendar
        )
        #expect(later.releases[0].cover == withCover.cover)
    }

    // MARK: - Apple

    private func song(_ collection: Int, _ name: String, artistID: Int, artist: String, day: String) -> AppleMusicClient.Song {
        AppleMusicClient.Song(
            wrapperType: "track", trackId: Int.random(in: 1...1_000_000), trackName: "track",
            artistId: artistID, artistName: artist, collectionId: collection, collectionName: name,
            collectionArtistName: nil, collectionViewUrl: nil, artworkUrl100: "https://example.com/100x100bb.jpg",
            releaseDate: day + "T07:00:00Z", trackNumber: 1, discNumber: 1, trackTimeMillis: 1000, trackCount: 1
        )
    }

    @Test func appleSongsFoldIntoReleases() {
        let releases = RadarLogic.releases(fromApple: [
            song(10, "Жоский (feat. madk1d) - Single", artistID: 2, artist: "KATASTROFA", day: "2026-10-01"),
            song(11, "sexyswag", artistID: 1, artist: "madk1d", day: "2025-03-14"),
            song(11, "sexyswag", artistID: 1, artist: "madk1d", day: "2025-03-21")
        ], artistID: 1)
            .sorted { $0.sourceID < $1.sourceID }

        #expect(releases.count == 2)
        #expect(releases[0].isFeature)
        #expect(releases[0].kind == .single)
        #expect(releases[0].displayTitle == "Жоский (feat. madk1d)")
        #expect(releases[0].cover?.absoluteString.contains("600x600bb") == true)
        // Альбом вышел в день последней из песен.
        #expect(!releases[1].isFeature)
        #expect(releases[1].kind == .album)
        #expect(releases[1].releaseDay == "2025-03-21")
    }

    @Test func compilationsAreNotReleases() {
        let mix = song(20, "Today's Hits: October 2026 (DJ Mix)", artistID: 9, artist: "Various", day: "2026-10-02")
        let various = AppleMusicClient.Song(
            wrapperType: "track", trackId: 5, trackName: "Loser", artistId: 1, artistName: "Tame Impala",
            collectionId: 21, collectionName: "relaxing girly shower", collectionArtistName: "Various Artists",
            collectionViewUrl: nil, artworkUrl100: nil, releaseDate: "2026-10-07T07:00:00Z",
            trackNumber: 1, discNumber: 1, trackTimeMillis: 1000, trackCount: 30
        )

        #expect(RadarLogic.releases(fromApple: [mix, various], artistID: 1).isEmpty)
    }

    @Test func dashSplitsArtistFromSong() {
        #expect(RadarText.variants(of: "Krewella - Alive (Remix)") == ["Krewella - Alive", "Krewella", "Alive"])
    }

    // MARK: - Сводка и расписание

    @Test func digestOfOneAndOfMany() {
        var one = release(1, "летник", day: "2026-10-08")
        one.libraryArtists = ["madk1d"]
        one.byline = "madk1d"
        #expect(RadarLogic.digest([one]).title == "madk1d")
        #expect(RadarLogic.digest([one]).body == "летник · single")

        var feature = release(2, "Жоский", day: "2026-10-08", isFeature: true)
        feature.libraryArtists = ["madk1d"]
        feature.byline = "KATASTROFA"
        #expect(RadarLogic.digest([feature]).title == "madk1d on KATASTROFA")

        let many = (1...5).map { index in
            var item = release(index, "Song \(index)", day: "2026-10-08")
            item.libraryArtists = ["Artist \(index)"]
            return item
        }
        let digest = RadarLogic.digest(many)
        #expect(digest.title == "5 new drops")
        #expect(digest.body == "Artist 1 — Song 1, Artist 2 — Song 2, Artist 3 — Song 3 and 2 more")
    }

    @Test func wakesForFridayMidnight() {
        // Четверг, 22:00 — пятничная полночь ближе, чем через четыре часа.
        let thursday = date(2026, 10, 8, hour: 22)
        #expect(ReleaseRadar.nextWakeUp(after: thursday, calendar: calendar)
            == calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 0, minute: 10)))

        let monday = date(2026, 10, 5, hour: 10)
        #expect(ReleaseRadar.nextWakeUp(after: monday, calendar: calendar) == monday.addingTimeInterval(4 * 3600))
    }
}
