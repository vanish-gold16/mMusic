import Foundation

/// Ремикс трека: скорость и тон, зал и эхо, глухость, бас, радио и 8D.
///
/// Хранится у самого трека, поэтому «замедленная» версия остаётся замедленной
/// и завтра. Все величины уходят в звуковой тракт как есть — см. `PlaybackEngine`.
///
/// В базе ремикс лежит не одним полем, а колонками в таблице треков — по колонке
/// на каждую ручку. Поэтому новые ручки добавляются только в конец и только
/// со значением «ничего не делает», а читаются терпимо (см. `init(from:)`).
struct RemixSettings: Codable, Equatable {

    /// Скорость: 0.5 — вдвое медленнее, 2 — вдвое быстрее.
    var speed: Double = 1
    /// Тон в полутонах: 12 — октава вверх.
    var pitch: Double = 0
    /// Сколько зала слышно на выходе, 0…100.
    var reverb: Double = 0
    /// «Винил»: тон едет за скоростью, как у пластинки, раскрученной не на своих
    /// оборотах. Именно это отличает ремикс от простого замедления — без связки
    /// голос остаётся на месте и звучит как растянутая запись, а не как другая.
    var isVinyl = false

    /// Глухость, 0…100: срезаются верхи — музыка играет за стеной, а в конце
    /// шкалы будто под водой.
    var muffle: Double = 0
    /// Бас в децибелах, −12…12: полка на самых низах.
    var bass: Double = 0
    /// Эхо, 0…100: повторы, которые тянутся за звуком и затихают.
    var echo: Double = 0
    /// 8D: звук ходит по кругу вокруг головы. Слышно в наушниках.
    var isOrbiting = false
    /// Радио: остаётся только середина, как у маленького динамика приёмника.
    var isRadio = false

    static let speedRange: ClosedRange<Double> = 0.5...2
    static let pitchRange: ClosedRange<Double> = -12...12
    static let reverbRange: ClosedRange<Double> = 0...100
    static let muffleRange: ClosedRange<Double> = 0...100
    static let bassRange: ClosedRange<Double> = -12...12
    static let echoRange: ClosedRange<Double> = 0...100

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

    /// Частота, выше которой глухость срезает звук. Шкала логарифмическая — от
    /// 20 кГц до 250 Гц: ухо слышит частоты октавами, и с прямой шкалой ручка
    /// почти ничего не делала бы до последней четверти хода.
    var muffleCutoff: Double {
        20_000 * pow(250.0 / 20_000, min(max(muffle, 0), 100) / 100)
    }

    /// Трек звучит так, как записан. Сравнение с допуском: ручка возвращается
    /// в середину не идеально ровно, а «почти единица» — это и есть единица.
    var isNeutral: Bool {
        abs(speed - 1) < 0.005 && abs(effectivePitch) < 0.05 && reverb < 0.5
            && muffle < 0.5 && abs(bass) < 0.25 && echo < 0.5
            && !isOrbiting && !isRadio
    }

    /// Значения за границами шкал в движок пускать нельзя: у реверба это просто
    /// бессмыслица, а у скорости — тишина или треск.
    func clamped() -> RemixSettings {
        var copy = self
        copy.speed = Self.clamp(speed, to: Self.speedRange)
        copy.pitch = Self.clamp(pitch, to: Self.pitchRange)
        copy.reverb = Self.clamp(reverb, to: Self.reverbRange)
        copy.muffle = Self.clamp(muffle, to: Self.muffleRange)
        copy.bass = Self.clamp(bass, to: Self.bassRange)
        copy.echo = Self.clamp(echo, to: Self.echoRange)
        return copy
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Совпадает ли на слух с другим набором. Нужно, чтобы подсветить пресет,
    /// на котором сейчас стоят ручки: сравнивать через `==` нельзя — одно и то же
    /// звучание набирается и связкой, и руками.
    func sounds(like other: RemixSettings) -> Bool {
        abs(speed - other.speed) < 0.01
            && abs(effectivePitch - other.effectivePitch) < 0.05
            && abs(reverb - other.reverb) < 0.5
            && abs(muffle - other.muffle) < 0.5
            && abs(bass - other.bass) < 0.25
            && abs(echo - other.echo) < 0.5
            && isOrbiting == other.isOrbiting
            && isRadio == other.isRadio
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
        Preset(name: "Hall", settings: RemixSettings(reverb: 60)),
        // Вечеринка за стеной: верхов почти нет, а гулкость комнаты осталась.
        Preset(name: "Next room", settings: RemixSettings(reverb: 30, muffle: 72)),
        Preset(name: "Underwater", settings: RemixSettings(speed: 0.9, reverb: 55, isVinyl: true, muffle: 90, echo: 12)),
        Preset(name: "Bass boost", settings: RemixSettings(bass: 12)),
        // Круг вокруг головы и немного зала, чтобы было, где кружить.
        Preset(name: "8D", settings: RemixSettings(reverb: 28, isOrbiting: true)),
        Preset(name: "Radio", settings: RemixSettings(reverb: 8, isRadio: true)),
        // Старая кассета: чуть медленнее, верхи притушены, низ потеплее.
        Preset(name: "Lo-fi", settings: RemixSettings(speed: 0.92, reverb: 15, isVinyl: true, muffle: 40, bass: 3)),
        Preset(name: "Dub", settings: RemixSettings(reverb: 12, muffle: 15, bass: 5, echo: 45)),
        Preset(name: "Dreamy", settings: RemixSettings(speed: 0.9, reverb: 75, isVinyl: true, muffle: 15, echo: 25)),
        // Только тон, без скорости: голос выше или ниже, темп прежний.
        Preset(name: "Chipmunk", settings: RemixSettings(pitch: 7)),
        Preset(name: "Deep", settings: RemixSettings(pitch: -5))
    ]
}

extension RemixSettings {

    /// Ремиксы, сохранённые до появления новых ручек, лежат в базе с пустыми
    /// колонками под них. Пустое читается как «ручка в нуле», а не как ошибка:
    /// иначе трек, который крутили раньше, потерял бы весь ремикс целиком.
    ///
    /// Объявлено в расширении, чтобы у структуры остался почленный
    /// инициализатор — на нём держатся пресеты.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        speed = try container.decodeIfPresent(Double.self, forKey: .speed) ?? 1
        pitch = try container.decodeIfPresent(Double.self, forKey: .pitch) ?? 0
        reverb = try container.decodeIfPresent(Double.self, forKey: .reverb) ?? 0
        isVinyl = try container.decodeIfPresent(Bool.self, forKey: .isVinyl) ?? false
        muffle = try container.decodeIfPresent(Double.self, forKey: .muffle) ?? 0
        bass = try container.decodeIfPresent(Double.self, forKey: .bass) ?? 0
        echo = try container.decodeIfPresent(Double.self, forKey: .echo) ?? 0
        isOrbiting = try container.decodeIfPresent(Bool.self, forKey: .isOrbiting) ?? false
        isRadio = try container.decodeIfPresent(Bool.self, forKey: .isRadio) ?? false
    }
}
