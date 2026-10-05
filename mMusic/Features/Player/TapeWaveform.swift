import Accelerate
import AVFoundation
import Foundation
import Observation

/// Подробная форма волны — для ленты под головкой плеера.
///
/// `Track.waveform` — 120 столбиков на весь трек: так трек виден целиком, и этого
/// хватает ленте плейлиста. Под головкой плеера лента идёт крупным планом, по два
/// десятка точек на секунду, и там нужна громкость каждой шестой доли секунды —
/// иначе вместо ударов видны размазанные холмы.
///
/// В модель такая волна не пишется: в ней тысячи чисел на трек, а нужна она только
/// играющему и его соседям по очереди. Считается при смене трека и живёт в памяти.
nonisolated struct TapeWaveform: Sendable {

    /// Сколько уровней приходится на секунду записи.
    static let levelsPerSecond: Double = 6

    /// Уровни 0...1, сжатые вдвое, вчетверо и дальше: отъехавшей ленте незачем
    /// рисовать тысячу столбиков на ширину экрана. `lods[0]` — полная подробность.
    let lods: [[Float]]
    /// Сколько секунд записи приходится на один уровень `lods[0]`.
    let secondsPerLevel: Double

    init(levels: [Float], secondsPerLevel: Double) {
        var lods = [levels]

        // Каждая следующая ступень — по максимуму из пары: громкий удар не должен
        // пропасть оттого, что сосед у него тихий.
        while let last = lods.last, last.count > 48 {
            lods.append(stride(from: 0, to: last.count, by: 2).map { index in
                index + 1 < last.count ? max(last[index], last[index + 1]) : last[index]
            })
        }

        self.lods = lods
        self.secondsPerLevel = secondsPerLevel
    }

    /// Волна из 120 столбиков модели, растянутая до той же частоты, — на то время,
    /// пока считается подробная. Между столбиками прямая: лента сначала выглядит
    /// плавными холмами, а потом проступает подробностями.
    init?(coarse data: Data, duration: TimeInterval) {
        let samples = Array(data)
        guard samples.count > 1, duration > 0 else { return nil }

        let count = max(Int(duration * Self.levelsPerSecond), 2)
        let levels = (0..<count).map { index -> Float in
            let position = Double(index) / Double(count - 1) * Double(samples.count - 1)
            let lower = Int(position)
            let upper = min(lower + 1, samples.count - 1)
            let fraction = Float(position - Double(lower))

            return (Float(samples[lower]) * (1 - fraction) + Float(samples[upper]) * fraction) / 255
        }

        self.init(levels: levels, secondsPerLevel: duration / Double(count))
    }

    /// Ступень подробности, при которой соседние столбики стоят не теснее `pitch` точек.
    func lod(forPointsPerSecond pointsPerSecond: Double, minimumPitch pitch: Double) -> Int {
        let finest = pointsPerSecond * secondsPerLevel
        guard finest > 0, finest < pitch else { return 0 }

        return min(Int(log2(pitch / finest).rounded(.up)), lods.count - 1)
    }

    /// Читает файл целиком и считает громкость каждой доли.
    ///
    /// Файл декодируется подряд, большими кусками: на трек уходит доля секунды.
    /// Окна вразбивку, как у `TrackWaveformLoader`, здесь не годятся — доли идут
    /// чаще ударов, и выборочные окна то попадали бы в бочку, то мимо неё.
    static func measure(_ url: URL) -> TapeWaveform? {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return nil }

        let format = file.processingFormat
        let bucket = max(AVAudioFramePosition(format.sampleRate / levelsPerSecond), 1)
        let count = Int((file.length + bucket - 1) / bucket)
        let chunk = AVAudioFrameCount(bucket * 32)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk),
              let channels = buffer.floatChannelData else { return nil }

        let channelCount = Int(format.channelCount)
        var energy = [Float](repeating: 0, count: count)
        var frames = [Int](repeating: 0, count: count)
        var position: AVAudioFramePosition = 0

        while position < file.length {
            do {
                try file.read(into: buffer, frameCount: chunk)
            } catch {
                break
            }

            let read = Int(buffer.frameLength)
            guard read > 0 else { break }

            var offset = 0
            while offset < read {
                let index = Int((position + AVAudioFramePosition(offset)) / bucket)
                guard index < count else { break }

                let bucketEnd = Int(AVAudioFramePosition(index + 1) * bucket - position)
                let length = min(read, bucketEnd) - offset

                for channel in 0..<channelCount {
                    var sum: Float = 0
                    vDSP_svesq(channels[channel] + offset, 1, &sum, vDSP_Length(length))
                    energy[index] += sum
                }

                frames[index] += length * channelCount
                offset += length
            }

            position += AVAudioFramePosition(read)
        }

        guard let levels = normalized(energy: energy, frames: frames) else { return nil }
        return TapeWaveform(levels: levels, secondsPerLevel: Double(bucket) / format.sampleRate)
    }

    /// Громкость каждой доли на 0...1. Складывается из двух вещей.
    ///
    /// Первая — где трек громкий, а где тихий: децибелы в коридоре 24 дБ под
    /// самым громким местом. Делением на пик, как у волны модели, здесь нельзя:
    /// у сведённой «в кирпич» записи почти всё лежит у пика, и лента выходила
    /// ровной колбасой. Вторая — удары: насколько доля громче своих соседей за
    /// полторы секунды в обе стороны. Без неё куплет — частокол одинаковых
    /// столбиков, с ней видно бочку и то, как вступает бит.
    private static func normalized(energy: [Float], frames: [Int]) -> [Float]? {
        let decibels = zip(energy, frames).map { energy, frames -> Float in
            guard frames > 0 else { return -100 }
            return 20 * log10(max((energy / Float(frames)).squareRoot(), 1e-5))
        }

        let sorted = decibels.sorted()
        guard let loudestSample = sorted.last, loudestSample > -100 else { return nil }

        // Самое громкое — не крайнее значение, а чуть внутри: один щелчок
        // не должен решать за весь трек.
        let loud = sorted[Int(Double(sorted.count - 1) * 0.995)]
        let reach = Int(levelsPerSecond * 1.5)

        return decibels.indices.map { index in
            let envelope = pow(min(max((decibels[index] - (loud - 24)) / 24, 0), 1), 1.6)

            // Медиана, а не среднее: один громкий удар не должен поднимать
            // планку всем соседям.
            let neighbours = decibels[max(index - reach, 0)..<min(index + reach, decibels.count)].sorted()
            let accent = min(max(decibels[index] - neighbours[neighbours.count / 2], -6), 6)

            // Удар масштабируется громкостью места: в тихом вступлении он
            // заметен, но не дорастает до припева.
            return min(max(envelope * (0.75 + accent / 8), 0), 1)
        }
    }
}

/// Подробные волны играющего трека и его соседей по очереди.
///
/// Хранит дюжину последних: вернуться к предыдущему треку — частое дело,
/// и считать его заново незачем. `@Observable` — чтобы лента перерисовалась,
/// как только подробная волна досчитается.
@Observable
final class TapeWaveformStore {

    static let shared = TapeWaveformStore()

    private(set) var detailed: [String: TapeWaveform] = [:]

    /// Растянутые волны модели — пока подробных нет. Не наблюдаются: их кладут
    /// сюда прямо во время отрисовки, и перерисовка на это не нужна.
    @ObservationIgnored private var coarse: [String: TapeWaveform] = [:]
    @ObservationIgnored private var recent: [String] = []
    @ObservationIgnored private var loading: [String: Task<TapeWaveform?, Never>] = [:]

    private let capacity = 12

    /// Лучшая волна трека, какая есть прямо сейчас: подробная, а пока её нет —
    /// растянутая из модели. nil — у трека не посчитана даже волна модели.
    func waveform(for track: Track, duration: TimeInterval) -> TapeWaveform? {
        if let waveform = detailed[track.filename] { return waveform }
        if let waveform = coarse[track.filename] { return waveform }

        guard let data = track.waveform, let waveform = TapeWaveform(coarse: data, duration: duration) else {
            return nil
        }

        if coarse.count > capacity * 2 { coarse.removeAll() }
        coarse[track.filename] = waveform
        return waveform
    }

    /// Считает подробную волну, если её ещё нет. Повторный вызов для того же трека,
    /// пока первый не закончил, ждёт его, а не читает файл второй раз.
    func load(_ track: Track) async {
        let filename = track.filename

        guard detailed[filename] == nil else {
            remember(filename)
            return
        }

        if let running = loading[filename] {
            _ = await running.value
            return
        }

        let url = AudioFileStore.url(for: filename)
        let task = Task.detached(priority: .utility) {
            TapeWaveform.measure(url)
        }

        loading[filename] = task
        let waveform = await task.value
        loading[filename] = nil

        guard let waveform else { return }

        detailed[filename] = waveform
        coarse[filename] = nil
        remember(filename)
    }

    private func remember(_ filename: String) {
        recent.removeAll { $0 == filename }
        recent.append(filename)

        while recent.count > capacity {
            detailed[recent.removeFirst()] = nil
        }
    }
}
