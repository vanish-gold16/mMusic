import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на ящики библиотеки: как буквы сливаются в диапазоны. Ошибка здесь
/// видна сразу — «#–A» или «X–Б» на разделителе, — но только на чужой фонотеке.
@MainActor
struct CrateTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func titles(_ names: [String], minimum: Int = 3) -> [String] {
        let albums = names.map { name -> Album in
            let album = Album(name: name, type: .LP)
            container.mainContext.insert(album)
            return album
        }

        let crates = Crate.grouping(albums, by: \.name.crateLetter)
        return Crate.mergingSparse(crates, minimum: minimum).map(\.title)
    }

    @Test func sparseLettersMergeIntoRanges() {
        let names = ["Abba", "Beatles", "Cream", "Doors", "Eagles", "Zappa"]

        #expect(titles(names) == ["A–C", "D–Z"])
    }

    @Test func fullLettersStayAlone() {
        let names = ["Abba", "Air", "Alt-J", "Beatles", "Bjork", "Blur"]

        #expect(titles(names) == ["A", "B"])
    }

    /// Одинокая буква в конце алфавита уходит к предыдущему ящику.
    @Test func lonelyTailJoinsThePreviousCrate() {
        let names = ["Abba", "Air", "Alt-J", "Zappa"]

        #expect(titles(names) == ["A–Z"])
    }

    /// «#–A» не читается.
    @Test func hashNeverMerges() {
        #expect(titles(["2Pac", "Abba"]) == ["#", "A"])
    }

    /// Латиница и кириллица — разные алфавиты, «Z–А» был бы не диапазоном.
    @Test func cyrillicDoesNotMergeWithLatin() {
        let names = ["Abba", "Zara", "Агата Кристи", "Би-2"]

        #expect(titles(names) == ["A–Z", "А–Б"])
    }

    @Test func letterIgnoresSpacesAndCase() {
        #expect(" abba".crateLetter == "A")
        #expect("ёлка".crateLetter == "Ё")
        #expect("2Pac".crateLetter == "#")
        #expect("🎵 Mix".crateLetter == "#")
    }
}
