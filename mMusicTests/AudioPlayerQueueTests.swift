import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на очередь: логика без UI, зато именно в ней ошибка стоит дороже всего.
/// Файлов у треков нет, поэтому `AVAudioPlayer` не создаётся — на состояние очереди
/// это не влияет, `playCurrent` меняет её до попытки открыть файл.
@MainActor
struct AudioPlayerQueueTests {

    /// Контейнер хранится в самом наборе тестов, а не создаётся внутри метода:
    /// стоит его отпустить — модели становятся невалидными и обращение к ним роняет
    /// процесс. Swift Testing создаёт экземпляр набора на каждый тест, так что
    /// база у каждого своя.
    private let container: ModelContainer
    /// Своё хранилище настроек на каждый тест: плеер сохраняет в него режимы,
    /// и с общим `UserDefaults.standard` один тест влиял бы на следующий —
    /// а заодно на настройки установленного приложения.
    private let defaults: UserDefaults
    private let suiteName: String

    init() throws {
        suiteName = "mMusicTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        AppSettings.registerDefaults(in: defaults)

        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makePlayer() -> AudioPlayer {
        AudioPlayer(defaults: defaults)
    }

    private func makeTracks(_ count: Int) -> [Track] {
        (0..<count).map { index in
            let track = Track(name: "Track \(index)", credits: [], genre: .pop, filename: "track\(index).mp3")
            container.mainContext.insert(track)
            return track
        }
    }

    @Test func playStartsAtGivenIndex() {
        let tracks = makeTracks(3)
        let player = makePlayer()

        player.play(tracks, startingAt: 1)

        #expect(player.queue.count == 3)
        #expect(player.currentIndex == 1)
        #expect(player.currentTrack?.name == "Track 1")
    }

    @Test func playIgnoresIndexOutsideTheList() {
        let tracks = makeTracks(2)
        let player = makePlayer()

        player.play(tracks, startingAt: 5)

        #expect(player.queue.isEmpty)
        #expect(player.currentTrack == nil)
    }

    @Test func nextStopsAtTheEndWithoutRepeat() {
        let tracks = makeTracks(2)
        let player = makePlayer()
        player.play(tracks, startingAt: 1)

        player.playNext()

        #expect(player.currentIndex == 1)
    }

    @Test func nextWrapsAroundWithRepeatAll() {
        let tracks = makeTracks(2)
        let player = makePlayer()
        player.repeatMode = .all
        player.play(tracks, startingAt: 1)

        player.playNext()

        #expect(player.currentIndex == 0)
    }

    @Test func enqueueNextInsertsRightAfterCurrent() {
        let tracks = makeTracks(4)
        let player = makePlayer()
        player.play(Array(tracks.prefix(3)), startingAt: 0)

        player.enqueueNext([tracks[3]])

        #expect(player.queue.map(\.name) == ["Track 0", "Track 3", "Track 1", "Track 2"])
        #expect(player.currentTrack?.name == "Track 0")
    }

    @Test func enqueueLastAppendsToTheEnd() {
        let tracks = makeTracks(3)
        let player = makePlayer()
        player.play(Array(tracks.prefix(2)), startingAt: 0)

        player.enqueueLast([tracks[2]])

        #expect(player.queue.last?.name == "Track 2")
    }

    @Test func enqueueOnEmptyQueueStartsPlayback() {
        let tracks = makeTracks(1)
        let player = makePlayer()

        player.enqueueNext(tracks)

        #expect(player.currentTrack?.name == "Track 0")
    }

    /// Индекс должен держаться за трек, а не за позицию: иначе удаление
    /// предыдущего трека подменяет играющий.
    @Test func forgetKeepsPointingAtTheSameTrack() {
        let tracks = makeTracks(3)
        let player = makePlayer()
        player.play(tracks, startingAt: 2)

        player.forget(tracks[0])

        #expect(player.queue.count == 2)
        #expect(player.currentTrack?.name == "Track 2")
    }

    @Test func forgettingCurrentTrackStopsPlayback() {
        let tracks = makeTracks(3)
        let player = makePlayer()
        player.play(tracks, startingAt: 1)

        player.forget(tracks[1])

        #expect(player.queue.count == 2)
        #expect(player.isPlaying == false)
        #expect(player.currentTrack?.name == "Track 2")
    }

    @Test func shuffleKeepsCurrentTrackAndRestoresOrder() {
        let tracks = makeTracks(6)
        let player = makePlayer()
        player.play(tracks, startingAt: 3)

        player.toggleShuffle()

        #expect(player.isShuffled)
        #expect(player.currentTrack?.name == "Track 3")
        #expect(Set(player.queue.map(\.name)).count == 6)

        player.toggleShuffle()

        #expect(player.isShuffled == false)
        #expect(player.queue.map(\.name) == tracks.map(\.name))
        #expect(player.currentTrack?.name == "Track 3")
    }

    @Test func movingInQueueFollowsTheCurrentTrack() {
        let tracks = makeTracks(3)
        let player = makePlayer()
        player.play(tracks, startingAt: 0)

        player.moveInQueue(from: IndexSet(integer: 0), to: 3)

        #expect(player.queue.map(\.name) == ["Track 1", "Track 2", "Track 0"])
        #expect(player.currentTrack?.name == "Track 0")
    }

    @Test func removingFromQueueDoesNotTouchOtherTracks() {
        let tracks = makeTracks(3)
        let player = makePlayer()
        player.play(tracks, startingAt: 2)

        player.removeFromQueue(at: IndexSet(integer: 0))

        #expect(player.queue.map(\.name) == ["Track 1", "Track 2"])
        #expect(player.currentTrack?.name == "Track 2")
    }

    @Test func repeatModeCyclesThroughAllStates() {
        let player = makePlayer()

        #expect(player.repeatMode == .off)
        player.cycleRepeatMode()
        #expect(player.repeatMode == .all)
        player.cycleRepeatMode()
        #expect(player.repeatMode == .one)
        player.cycleRepeatMode()
        #expect(player.repeatMode == .off)
    }
}
