import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на то, что показывает плеер: номер трека на пластинке в паспорте
/// и подробную волну ленты под головкой.
@MainActor
struct PlayerTapeTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeAlbum(_ type: Album.AlbumType = .LP, discs: [Int]) -> (Album, [Track]) {
        let album = Album(name: "Outrun", type: type)
        container.mainContext.insert(album)
        if discs.count > 1 {
            album.discTitles = discs.map { _ in "" }
        }

        var tracks: [Track] = []
        for (disc, count) in discs.enumerated() {
            for _ in 0..<count {
                let index = tracks.count
                let track = Track(name: "Track \(index)", credits: [], genre: .pop, filename: "track\(index).mp3")
                track.position = index
                track.disc = disc
                track.duration = 200
                track.album = album
                container.mainContext.insert(track)
                tracks.append(track)
            }
        }

        return (album, tracks)
    }

    // MARK: - Номер на пластинке

    /// Шесть равных треков — две стороны по три: третий ещё на A, четвёртый уже на B.
    @Test func numberCarriesTheSideLetter() {
        let (album, tracks) = makeAlbum(discs: [6])

        #expect(album.recordNumber(of: tracks[2]) == "A3")
        #expect(album.recordNumber(of: tracks[3]) == "B1")
    }

    /// Короче четырёх треков пластинка не делится на стороны — номер без буквы.
    @Test func shortRecordIsNumberedWithoutSides() {
        let (album, tracks) = makeAlbum(discs: [3])

        #expect(album.recordNumber(of: tracks[1]) == "track 2")
    }

    /// У пластинки из одного трека номера нет: «track 1» ничего не сообщает.
    @Test func lonelyTrackHasNoNumber() {
        let (album, tracks) = makeAlbum(.single, discs: [1])

        #expect(album.recordNumber(of: tracks[0]) == nil)
    }

    /// Вторая пластинка двойного альбома — стороны C и D, счёт с начала пластинки.
    @Test func secondDiscIsLetteredCAndD() {
        let (album, tracks) = makeAlbum(discs: [4, 4])

        #expect(album.recordNumber(of: tracks[4]) == "C1")
        #expect(album.recordNumber(of: tracks[7]) == "D2")
    }

    @Test func trackFromAnotherAlbumHasNoNumber() {
        let (album, _) = makeAlbum(discs: [6])
        let (_, others) = makeAlbum(discs: [6])

        #expect(album.recordNumber(of: others[0]) == nil)
    }

    // MARK: - Волна ленты

    /// Ступени сжимаются вдвое, пока не станут короткими, и громкий удар доживает
    /// до самой грубой: по максимуму, а не по среднему.
    @Test func coarserLevelsKeepTheLoudestBeat() {
        var levels = [Float](repeating: 0.1, count: 200)
        levels[137] = 1

        let waveform = TapeWaveform(levels: levels, secondsPerLevel: 1.0 / 6)

        #expect(waveform.lods.map(\.count) == [200, 100, 50, 25])
        #expect(waveform.lods.allSatisfy { $0.max() == 1 })
    }

    /// Крупный план рисуется полной подробностью, отъехавшая лента — грубой ступенью,
    /// чтобы столбики не слиплись.
    @Test func zoomPicksTheLevelOfDetail() {
        let waveform = TapeWaveform(levels: [Float](repeating: 0.5, count: 1500), secondsPerLevel: 1.0 / 6)

        #expect(waveform.lod(forPointsPerSecond: 22, minimumPitch: 3.4) == 0)
        // 1.5 точки на секунду: самая тонкая ступень дала бы 0.25 точки на столбик,
        // нужно сжать в 16 раз.
        #expect(waveform.lod(forPointsPerSecond: 1.5, minimumPitch: 3.4) == 4)
        // Дальше самой грубой ступени не уходит.
        #expect(waveform.lod(forPointsPerSecond: 0.001, minimumPitch: 3.4) == waveform.lods.count - 1)
    }

    /// Волна модели растягивается на ту же частоту, концы остаются на месте.
    @Test func coarseWaveformStretchesToTheTapeRate() throws {
        let samples = Data((0..<120).map { UInt8($0 * 2) })

        let waveform = try #require(TapeWaveform(coarse: samples, duration: 60))
        let levels = waveform.lods[0]

        #expect(levels.count == 360)
        #expect(levels.first == 0)
        #expect(abs((levels.last ?? 0) - Float(238) / 255) < 0.0001)
        #expect(abs(waveform.secondsPerLevel - 60.0 / 360) < 0.0001)
    }
}
