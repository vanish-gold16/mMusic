import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Раскладка по пластинкам в редакторе: перетаскивание границ и треков
/// не должно терять ни треков, ни названий пластинок.
struct DiscSplitTests {

    private func split() -> DiscSplit<String> {
        DiscSplit(discs: [["a", "b", "c"], ["d", "e"]], titles: ["First", "Second"])
    }

    @Test func rowsPutABoundaryBeforeEveryDiscButTheFirst() {
        #expect(split().rows == [.track("a"), .track("b"), .track("c"), .boundary(1), .track("d"), .track("e")])
    }

    /// Граница на строку выше — последний трек первой пластинки уезжает на вторую.
    @Test func movingABoundaryUpMovesATrackToTheNextDisc() {
        var split = split()
        split.move(fromOffsets: [3], toOffset: 2)

        #expect(split.discs == [["a", "b"], ["c", "d", "e"]])
        #expect(split.titles == ["First", "Second"])
    }

    @Test func draggingATrackPastTheBoundaryChangesItsDisc() {
        var split = split()
        split.move(fromOffsets: [0], toOffset: 6)

        #expect(split.discs == [["b", "c"], ["d", "e", "a"]])
    }

    /// Убранная граница сливает пластинки, и ни один трек не теряется.
    @Test func removingABoundaryMergesIntoThePreviousDisc() {
        var split = split()
        split.removeBoundaries(atOffsets: [3])

        #expect(split.discs == [["a", "b", "c", "d", "e"]])
        #expect(split.titles == ["First"])
    }

    /// Название едет вместе со своей границей, а не остаётся на месте.
    @Test func titlesFollowTheirBoundaries() {
        var split = DiscSplit(discs: [["a"], ["b"], ["c"]], titles: ["One", "Two", "Three"])
        // Граница третьей пластинки — над границей второй.
        split.move(fromOffsets: [3], toOffset: 1)

        #expect(split.discs == [["a"], [], ["b", "c"]])
        #expect(split.titles == ["One", "Three", "Two"])
    }

    @Test func removingTracksKeepsTheDiscs() {
        var split = split()
        split.removeTracks(["d", "e"])

        #expect(split.discs == [["a", "b", "c"], []])
    }

    @Test func titlesArePaddedToTheNumberOfDiscs() {
        let split = DiscSplit(discs: [["a"], ["b"]], titles: [])
        #expect(split.titles == ["", ""])
    }

    @Test func boundaryNumbersCountFromTwo() {
        var split = split()
        split.appendDisc()
        let rows = split.rows

        let numbers = rows.indices.compactMap { index -> Int? in
            if case .boundary = rows[index] { return split.number(ofBoundaryAt: index) }
            return nil
        }
        #expect(numbers == [2, 3])
    }
}

/// Пластинки в самой модели: номера в альбоме идут подряд пластинка
/// за пластинкой — на этом держится всё, что сортирует альбом по `position`.
@MainActor
struct AlbumDiscTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeAlbum(trackCount: Int) -> (Album, [Track]) {
        let album = Album(name: "Double", type: .LP)
        container.mainContext.insert(album)

        let tracks = (0..<trackCount).map { index -> Track in
            let track = Track(name: "Track \(index)", credits: [], genre: .pop, filename: "disc\(index).mp3")
            container.mainContext.insert(track)
            return track
        }
        album.append(tracks)

        return (album, tracks)
    }

    @Test func oldAlbumsHaveOneDisc() {
        let (album, tracks) = makeAlbum(trackCount: 3)

        #expect(album.discCount == 1)
        #expect(album.discs.map { $0.map(\.name) } == [tracks.map(\.name)])
    }

    @Test func arrangeNumbersDiscByDisc() {
        let (album, tracks) = makeAlbum(trackCount: 4)
        album.arrange([[tracks[2], tracks[0]], [tracks[3], tracks[1]]], titles: ["", "Live"])

        #expect(album.discCount == 2)
        #expect(album.discTitles == ["", "Live"])
        #expect(album.discs.map { $0.map(\.name) } == [["Track 2", "Track 0"], ["Track 3", "Track 1"]])
        #expect(album.isNumberedInOrder)
    }

    /// Новое ложится в конец альбома — на последнюю пластинку.
    @Test func appendGoesToTheLastDisc() {
        let (album, tracks) = makeAlbum(trackCount: 2)
        album.arrange([[tracks[0]], [tracks[1]]], titles: ["", ""])

        let newcomer = Track(name: "New", credits: [], genre: .pop, filename: "new.mp3")
        container.mainContext.insert(newcomer)
        album.append([newcomer])

        #expect(newcomer.disc == 1)
        #expect(album.discs.last?.map(\.name) == ["Track 1", "New"])
        #expect(album.isNumberedInOrder)
    }

    /// Одна пластинка — названий не хранится: пустой список и значит «пластинка одна».
    @Test func arrangingIntoOneDiscDropsTheTitles() {
        let (album, tracks) = makeAlbum(trackCount: 2)
        album.arrange([[tracks[0]], [tracks[1]]], titles: ["A", "B"])
        album.arrange([tracks], titles: ["A"])

        #expect(album.discTitles.isEmpty)
        #expect(tracks.allSatisfy { $0.disc == 0 })
    }

    /// Номера подряд, но пластинки вперемешку — починка на запуске это замечает
    /// и раскладывает треки обратно пластинка за пластинкой.
    @Test func repairRegroupsInterleavedDiscs() {
        let (album, tracks) = makeAlbum(trackCount: 3)
        album.discTitles = ["", ""]
        tracks[0].disc = 1
        tracks[1].disc = 0
        tracks[2].disc = 1

        #expect(!album.isNumberedInOrder)
        album.renumberTracks()

        #expect(album.isNumberedInOrder)
        #expect(album.discs.map { $0.map(\.name) } == [["Track 1"], ["Track 0", "Track 2"]])
    }

    /// Трек из альбома, где пластинок было больше, ложится на последнюю.
    @Test func discNumbersBeyondTheAlbumAreClamped() {
        let (album, tracks) = makeAlbum(trackCount: 1)
        tracks[0].disc = 5

        #expect(album.discs.map(\.count) == [1])
    }
}
