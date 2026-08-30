import AVFoundation
import Foundation
import Testing
@testable import mMusic

/// Тесты на звуковой тракт: позиция, скорость, перемотка и пауза.
///
/// Работают на настоящем движке и настоящем файле — иначе проверять нечего:
/// вся суть `PlaybackEngine` в том, что он сам считает то, что раньше давал
/// `AVAudioPlayer`. Поэтому здесь есть ожидания по времени, и допуски широкие:
/// проверяется порядок величины, а не точность до кадра.
@MainActor
struct PlaybackEngineTests {

    private let filename: String

    init() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)

        filename = "engine-test-\(UUID().uuidString).wav"
        try Self.writeTone(to: AudioFileStore.url(for: filename), seconds: 20)
    }

    /// Ровный тон: содержимое неважно, важна длина и то, что файл настоящий.
    private static func writeTone(to url: URL, seconds: Double) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(44100 * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        for channel in 0..<2 {
            for index in 0..<Int(frames) {
                let time = Double(index) / 44100
                buffer.floatChannelData![channel][index] = Float(sin(2 * .pi * 220 * time) * 0.3)
            }
        }

        try file.write(from: buffer)
    }

    private func makeEngine() throws -> PlaybackEngine {
        let engine = PlaybackEngine()
        try engine.load(AudioFileStore.url(for: filename))
        return engine
    }

    private func cleanUp() {
        AudioFileStore.remove(filename: filename)
    }

    @Test func positionFollowsRealTime() async throws {
        let engine = try makeEngine()
        defer { engine.stop(); cleanUp() }

        #expect(abs(engine.duration - 20) < 0.1)

        engine.play()
        try await Task.sleep(for: .seconds(1))

        #expect(engine.currentTime > 0.7 && engine.currentTime < 1.4)
    }

    /// На половинной скорости позиция в треке идёт вдвое медленнее реального времени.
    @Test func speedChangesHowFastPositionMoves() async throws {
        let engine = try makeEngine()
        defer { engine.stop(); cleanUp() }

        engine.apply(RemixSettings(speed: 0.5, isVinyl: true))
        engine.play()
        try await Task.sleep(for: .seconds(1))

        #expect(engine.currentTime > 0.25 && engine.currentTime < 0.8)
    }

    /// Перемотка обрывает расписание, и его completion приходит так же, как
    /// у доигравшего трека. Без защиты это выглядело бы как «трек кончился»,
    /// и очередь уезжала бы на следующий.
    @Test func seekDoesNotLookLikeTheEndOfTheTrack() async throws {
        let engine = try makeEngine()
        defer { engine.stop(); cleanUp() }

        var finished = false
        engine.onFinish = { finished = true }

        engine.play()
        try await Task.sleep(for: .milliseconds(300))

        engine.seek(to: 10)
        try await Task.sleep(for: .milliseconds(400))

        #expect(!finished, "перемотка приняла обрыв расписания за конец трека")
        #expect(engine.currentTime > 10 && engine.currentTime < 11)
    }

    /// Трек доиграл до конца, и его включают снова. Узел не обнуляет свой счётчик
    /// сам — без остановки перед новым расписанием позиция считалась бы от конца
    /// прошлого проигрывания: звук идёт с начала, а ползунок стоит в конце.
    @Test func replayAfterTheEndStartsFromTheBeginning() async throws {
        let shortFilename = "engine-test-short-\(UUID().uuidString).wav"
        try Self.writeTone(to: AudioFileStore.url(for: shortFilename), seconds: 1)
        defer { AudioFileStore.remove(filename: shortFilename) }

        let engine = PlaybackEngine()
        defer { engine.stop() }
        try engine.load(AudioFileStore.url(for: shortFilename))

        var finished = false
        engine.onFinish = { finished = true }

        engine.play()
        try await Task.sleep(for: .milliseconds(1500))
        #expect(finished, "трек не доиграл до конца")

        engine.play()
        try await Task.sleep(for: .milliseconds(400))

        #expect(
            engine.currentTime > 0.1 && engine.currentTime < 0.8,
            "повторный запуск считает позицию от конца прошлого проигрывания"
        )
    }

    @Test func pauseFreezesPosition() async throws {
        let engine = try makeEngine()
        defer { engine.stop(); cleanUp() }

        engine.play()
        try await Task.sleep(for: .milliseconds(500))
        engine.pause()

        let paused = engine.currentTime
        try await Task.sleep(for: .milliseconds(400))
        #expect(engine.currentTime == paused)

        engine.play()
        try await Task.sleep(for: .milliseconds(400))
        #expect(engine.currentTime > paused)
    }
}
