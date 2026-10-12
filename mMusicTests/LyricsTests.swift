import Foundation
import Testing
@testable import mMusic

/// Тесты на разбор статического текста трека: текст приходит копипастой откуда
/// угодно, и ломается разбор именно на чужих переносах строк.
struct LyricsTests {

    @Test func splitsStanzasOnBlankLine() {
        let stanzas = Lyrics.stanzas(of: "one\ntwo\n\nthree")

        #expect(stanzas == ["one\ntwo", "three"])
    }

    /// Пустых строк подряд может быть сколько угодно — куплетов от этого не прибавляется.
    @Test func collapsesRepeatedBlankLines() {
        let stanzas = Lyrics.stanzas(of: "\n\none\n\n  \n\ntwo\n\n")

        #expect(stanzas == ["one", "two"])
    }

    /// `\r\n` из Windows не должен превращать каждый перенос в разрыв куплета.
    @Test func handlesWindowsLineEndings() {
        let stanzas = Lyrics.stanzas(of: "one\r\ntwo\r\n\r\nthree")

        #expect(stanzas == ["one\ntwo", "three"])
    }

    @Test func trimsTrailingSpacesInsideLines() {
        let stanzas = Lyrics.stanzas(of: "  one  \n  two")

        #expect(stanzas == ["one\ntwo"])
    }

    @Test func blankTextIsNotStored() {
        #expect(Lyrics.normalized("   \n\n  ") == nil)
        #expect(Lyrics.normalized("") == nil)
        #expect(Lyrics.normalized("\n text \n") == "text")
    }

    @Test func emptyTrackHasNoLyrics() {
        let track = Track(name: "Test", credits: [], genre: .pop, filename: "test.mp3")
        #expect(track.hasLyrics == false)

        track.lyrics = "   "
        #expect(track.hasLyrics == false)

        track.lyrics = "la la la"
        #expect(track.hasLyrics)
    }
}

/// Тесты на разбор LRC — текста с таймкодами, который приходит из LRCLIB.
struct SyncedLyricsTests {

    @Test func readsTimedLines() {
        let lines = Lyrics.synced("[00:01.50] first line\n[00:04.25] second line\n[01:02.00] third")

        #expect(lines == [
            Lyrics.Line(time: 1.5, text: "first line"),
            Lyrics.Line(time: 4.25, text: "second line"),
            Lyrics.Line(time: 62, text: "third")
        ])
    }

    /// Обычный текст — не LRC, даже если в нём есть квадратные скобки.
    @Test func plainTextIsNotSynced() {
        #expect(Lyrics.synced("one\ntwo\n\nthree") == nil)
        #expect(Lyrics.synced("[Chorus]\nla la\n[Verse 2]\nna na") == nil)
        #expect(Lyrics.synced("") == nil)
    }

    /// Одна случайная метка в заметке не делает её синхронной.
    @Test func oneStampInANoteIsNotEnough() {
        #expect(Lyrics.synced("[00:30] the good part\nsomething\nsomething else") == nil)
    }

    /// Метка без слов — проигрыш, он остаётся строкой с пустым текстом.
    @Test func keepsInstrumentalBreaks() {
        let lines = Lyrics.synced("[00:01.00] sing\n[00:05.00]\n[00:09.00] again")

        #expect(lines?.map(\.text) == ["sing", "", "again"])
    }

    /// У припева бывает несколько меток сразу — он звучит каждый раз.
    @Test func expandsRepeatedChorus() {
        let lines = Lyrics.synced("[00:10.00][00:30.00] chorus\n[00:20.00] verse")

        #expect(lines == [
            Lyrics.Line(time: 10, text: "chorus"),
            Lyrics.Line(time: 20, text: "verse"),
            Lyrics.Line(time: 30, text: "chorus")
        ])
    }

    @Test func skipsFileTagsAndAppliesOffset() {
        let lines = Lyrics.synced("[ar: Someone]\n[ti: Something]\n[offset:+500]\n[00:02.00] hello")

        #expect(lines == [Lyrics.Line(time: 1.5, text: "hello")])
    }

    /// «[Chorus: имя]» — это слова песни, а не подпись файла: не пропадает.
    @Test func sectionHeadersAreNotFileTags() {
        let lines = Lyrics.synced("[Chorus: Someone]\n[00:01.00] one\n[00:02.00] two")

        #expect(lines?.first == Lyrics.Line(time: 0, text: "[Chorus: Someone]"))
    }

    /// Строка без метки внутри LRC продолжает предыдущую, а не теряется.
    @Test func untimedLineJoinsPrevious() {
        let lines = Lyrics.synced("[00:01.00] one\nstill one\n[00:03.00] two")

        #expect(lines == [
            Lyrics.Line(time: 1, text: "one\nstill one"),
            Lyrics.Line(time: 3, text: "two")
        ])
    }

    @Test func stripsWordStamps() {
        let lines = Lyrics.synced("[00:01.00] <00:01.00> one <00:01.40> two")

        #expect(lines?.first?.text == "one two")
    }

    @Test func readsOtherStampShapes() {
        let lines = Lyrics.synced("[1:02] a\n[01:03:50] b\n[01:04.250] c")

        #expect(lines?.map(\.time) == [62, 63.5, 64.25])
    }

    @Test func plainDropsStampsAndKeepsStanzas() {
        let text = "[00:01.00] one\n[00:02.00] two\n[00:03.00]\n[00:04.00] three"

        #expect(Lyrics.plain(text) == "one\ntwo\n\nthree")
        #expect(Lyrics.plain("just words") == "just words")
    }

    @Test func activeLineIsTheLastStarted() {
        let lines = [
            Lyrics.Line(time: 5, text: "a"),
            Lyrics.Line(time: 10, text: "b"),
            Lyrics.Line(time: 15, text: "c")
        ]

        #expect(Lyrics.activeIndex(in: lines, at: 2) == nil)
        #expect(Lyrics.activeIndex(in: lines, at: 5) == 0)
        #expect(Lyrics.activeIndex(in: lines, at: 12) == 1)
        #expect(Lyrics.activeIndex(in: lines, at: 300) == 2)
    }
}
