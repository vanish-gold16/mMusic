import Foundation

/// Ремикс трека: скорость, тон и эхо, с которыми его слушают.
///
/// Хранится у самого трека, поэтому «замедленная» версия остаётся замедленной
/// и завтра. Все три величины уходят в звуковой тракт как есть — см. `PlaybackEngine`.
struct RemixSettings: Codable, Equatable {

    /// Скорость: 0.5 — вдвое медленнее, 2 — вдвое быстрее.
    var speed: Double = 1
    /// Тон в полутонах: 12 — октава вверх.
    var pitch: Double = 0
    /// Сколько эха слышно на выходе, 0…100.
    var reverb: Double = 0
    /// «Винил»: тон едет за скоростью, как у пластинки, раскрученной не на своих
    /// оборотах. Именно это отличает ремикс от простого замедления — без связки
    /// голос остаётся на месте и звучит как растянутая запись, а не как другая.
    var isVinyl = false

    static let speedRange: ClosedRange<Double> = 0.5...2
    static let pitchRange: ClosedRange<Double> = -12...12
    static let reverbRange: ClosedRange<Double> = 0...100

    static let neutral = RemixSettings()

    /// Тон, который реально уходит в движок.
    var effectivePitch: Double {
        isVinyl ? Self.pitch(forSpeed: speed) : pitch
    }

    /// Пластинка, раскрученная в k раз, звучит выше на 12·log₂(k) полутонов:
    /// удвоение скорости — ровно октава.
    static func pitch(forSpeed speed: Double) -> Double {
        12 * log2(max(speed, 0.01))
    }

    /// Трек звучит так, как записан. Сравнение с допуском: ручка возвращается
    /// в середину не идеально ровно, а «почти единица» — это и есть единица.
    var isNeutral: Bool {
        abs(speed - 1) < 0.005 && abs(effectivePitch) < 0.05 && reverb < 0.5
    }

    /// Значения за границами шкал в движок пускать нельзя: у реверба это просто
    /// бессмыслица, а у скорости — тишина или треск.
    func clamped() -> RemixSettings {
        var copy = self
        copy.speed = min(max(speed, Self.speedRange.lowerBound), Self.speedRange.upperBound)
        copy.pitch = min(max(pitch, Self.pitchRange.lowerBound), Self.pitchRange.upperBound)
        copy.reverb = min(max(reverb, Self.reverbRange.lowerBound), Self.reverbRange.upperBound)
        return copy
    }

    /// Совпадает ли на слух с другим набором. Нужно, чтобы подсветить пресет,
    /// на котором сейчас стоят ручки: сравнивать через `==` нельзя — одно и то же
    /// звучание набирается и связкой, и руками.
    func sounds(like other: RemixSettings) -> Bool {
        abs(speed - other.speed) < 0.01
            && abs(effectivePitch - other.effectivePitch) < 0.05
            && abs(reverb - other.reverb) < 0.5
    }

    /// Готовый ремикс одной кнопкой. Дальше его можно докрутить руками —
    /// пресет только расставляет ручки.
    struct Preset: Identifiable, Equatable {
        let name: String
        let settings: RemixSettings

        var id: String { name }
    }

    static let presets: [Preset] = [
        Preset(name: "Original", settings: .neutral),
        // Классический «slowed + reverb»: чуть медленнее, тон уезжает вниз вместе
        // со скоростью, и всё это в большом зале.
        Preset(name: "Slowed", settings: RemixSettings(speed: 0.85, reverb: 45, isVinyl: true)),
        Preset(name: "Nightcore", settings: RemixSettings(speed: 1.25, reverb: 12, isVinyl: true)),
        // Тон вниз без связки: скорость своя, «толщина» своя.
        Preset(name: "Screwed", settings: RemixSettings(speed: 0.7, pitch: -3, reverb: 30)),
        // Только зал: скорость и тон не трогаем.
        Preset(name: "Hall", settings: RemixSettings(reverb: 60))
    ]
}
