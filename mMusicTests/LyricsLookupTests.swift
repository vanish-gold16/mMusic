import Foundation
import Testing
@testable import mMusic

/// Тесты на выбор записи из LRCLIB: одна песня лежит в базе много раз —
/// с альбома, с концерта, под чужим артистом, — и ошибиться легко.
struct LyricsLookupTests {

    private let synced = "[00:01.00] made up line\n[00:03.00] another made up line"
    private let plain = "made up line\nanother made up line"

    private func record(
        _ id: Int,
        track: String = "Night Drive",
        artist: String = "Paper Lanterns",
        duration: Double? = 200,
        instrumental: Bool = false,
        plain: String? = nil,
        synced: String? = nil
    ) -> LRCLibClient.Record {
        LRCLibClient.Record(
            id: id, trackName: track, artistName: artist, albumName: nil,
            duration: duration, instrumental: instrumental,
            plainLyrics: plain, syncedLyrics: synced
        )
    }

    private let query = LyricsLookup.Query(title: "Night Drive", artists: ["Paper Lanterns"], duration: 201)

    /// Концертная версия длиннее — её таймкоды уехали бы от музыки.
    @Test func prefersTheRecordingOfTheSameLength() {
        let live = record(1, duration: 260, plain: plain, synced: "[00:10.00] made up line")
        let studio = record(2, duration: 200, plain: plain, synced: synced)

        #expect(LyricsLookup.pick(from: [live, studio], for: query) == .lyrics(synced, isSynced: true))
    }

    /// Нашлась только запись другой длины — слова берутся, таймкоды нет.
    @Test func dropsTimingOfAnotherRecording() {
        let live = record(1, duration: 260, synced: synced)

        #expect(LyricsLookup.pick(from: [live], for: query) == .lyrics(plain, isSynced: false))
    }

    /// Артиста база пишет по-своему, но длина совпала — это та же песня.
    @Test func sameLengthOutweighsArtistSpelling() {
        let other = record(1, artist: "Bumazhnye Fonari", duration: 202, synced: synced)

        #expect(LyricsLookup.pick(from: [other], for: query) == .lyrics(synced, isSynced: true))
    }

    /// Чужой артист и другая длина — тёзка, а не наш трек.
    @Test func rejectsNamesakes() {
        let namesake = record(1, artist: "Someone Else", duration: 150, synced: synced)

        #expect(LyricsLookup.pick(from: [namesake], for: query) == nil)
    }

    @Test func rejectsOtherTitles() {
        let other = record(1, track: "Morning Walk", synced: synced)

        #expect(LyricsLookup.pick(from: [other], for: query) == nil)
    }

    /// Приписки из YouTube в названии не мешают узнать песню.
    @Test func matchesDirtyLibraryTitles() {
        let dirty = LyricsLookup.Query(title: "Night Drive (Official Video)", artists: ["Paper Lanterns"], duration: 200)

        #expect(LyricsLookup.pick(from: [record(1, synced: synced)], for: dirty) == .lyrics(synced, isSynced: true))
    }

    @Test func reportsInstrumental() {
        let bare = record(1, instrumental: true)

        #expect(LyricsLookup.pick(from: [bare], for: query) == .instrumental)
    }

    /// Запись со словами важнее записи, где трек пометили инструменталом.
    @Test func wordsBeatAnInstrumentalMark() {
        let bare = record(1, instrumental: true)
        let words = record(2, plain: plain)

        #expect(LyricsLookup.pick(from: [bare, words], for: query) == .lyrics(plain, isSynced: false))
    }

    /// Пустые записи пропускаются — в базе бывают заготовки без текста.
    @Test func skipsEmptyRecords() {
        #expect(LyricsLookup.pick(from: [record(1, plain: "  ")], for: query) == nil)
    }

    /// Длина трека ещё не измерена — таймкоды берутся на веру.
    @Test func unknownDurationKeepsTiming() {
        let unknown = LyricsLookup.Query(title: "Night Drive", artists: ["Paper Lanterns"], duration: 0)

        #expect(LyricsLookup.pick(from: [record(1, synced: synced)], for: unknown) == .lyrics(synced, isSynced: true))
    }

    @Test func searchesCleanTitleWhenDirty() {
        let dirty = LyricsLookup.Query(title: "Night Drive (Official Video)", artists: ["Paper Lanterns"], duration: 200)

        #expect(LyricsLookup.searches(for: dirty) == [
            .fields(track: "Night Drive (Official Video)", artist: "Paper Lanterns"),
            .fields(track: "Night Drive", artist: "Paper Lanterns"),
            .words("Paper Lanterns Night Drive")
        ])
    }

    /// Артист уже вписан в название — второй раз в запрос он не идёт.
    @Test func doesNotRepeatArtistInWords() {
        let named = LyricsLookup.Query(title: "Paper Lanterns - Night Drive", artists: ["Paper Lanterns"], duration: 200)

        #expect(LyricsLookup.searches(for: named).last == .words("Paper Lanterns - Night Drive"))
    }
}
