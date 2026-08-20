import AVFoundation
import Foundation

/// Считает форму волны трека — громкость по всей его длине.
///
/// Файл читается один раз, результат живёт в `Track.waveform`: 120 байт на трек,
/// поэтому его не жалко держать прямо в модели и не нужно считать заново при каждом показе.
enum TrackWaveformLoader {

    /// Столбиков в волне. На такой ширине читаются куплеты и припев,
    /// а рисование остаётся дешёвым.
    nonisolated static let resolution = 120

    nonisolated static func fill(_ tracks: [Track]) async {
        for track in tracks {
            guard !Task.isCancelled else { return }

            guard let waveform = await makeWaveform(for: AudioFileStore.url(for: track.filename)) else { continue }

            track.waveform = waveform
        }
    }

    /// Считает волну одного трека и запоминает её. Плеер зовёт это для играющего трека:
    /// общий проход идёт по библиотеке подряд и до нужного может дойти нескоро.
    nonisolated static func fill(_ track: Track) async {
        guard track.waveform == nil else { return }
        guard let waveform = await makeWaveform(for: AudioFileStore.url(for: track.filename)) else { return }

        track.waveform = waveform
    }

    /// Чтение и возведение в квадрат сотен тысяч сэмплов — работа не для главного потока.
    private nonisolated static func makeWaveform(for url: URL) async -> Data? {
        await Task.detached(priority: .utility) {
            guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return nil }

            let framesPerBucket = AVAudioFrameCount(max(1, file.length / Int64(resolution)))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: framesPerBucket) else {
                return nil
            }

            var buckets: [Float] = []
            buckets.reserveCapacity(resolution)

            while buckets.count < resolution {
                do {
                    try file.read(into: buffer, frameCount: framesPerBucket)
                } catch {
                    break
                }

                guard buffer.frameLength > 0, let channel = buffer.floatChannelData?[0] else { break }

                // Среднеквадратичное, а не пик: пик дал бы частокол одинаковой высоты.
                var sum: Float = 0
                for index in 0..<Int(buffer.frameLength) {
                    let sample = channel[index]
                    sum += sample * sample
                }

                buckets.append((sum / Float(buffer.frameLength)).squareRoot())
            }

            return normalized(buckets)
        }.value
    }

    /// Делим на пик — иначе тихая запись нарисовалась бы плоской линией.
    /// Корень поверх сжимает динамику: без него на фоне громкого припева
    /// весь остальной трек выглядит пустым местом.
    private nonisolated static func normalized(_ buckets: [Float]) -> Data? {
        guard let peak = buckets.max(), peak > 0 else { return nil }

        var bytes = buckets.map { UInt8(min(255, (($0 / peak).squareRoot() * 255).rounded())) }

        // Короткий трек мог не набрать полного числа столбиков — добиваем тишиной.
        bytes.append(contentsOf: repeatElement(0, count: max(0, resolution - bytes.count)))

        return Data(bytes)
    }
}
