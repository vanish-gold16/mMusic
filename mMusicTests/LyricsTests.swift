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
