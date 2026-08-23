import Foundation

/// Режим повтора очереди.
enum RepeatMode: String, CaseIterable {
    /// Доиграли последний трек — остановились.
    case off
    /// После последнего идёт первый.
    case all
    /// Один и тот же трек по кругу.
    case one

    /// Порядок обхода по нажатию кнопки: выкл → вся очередь → один трек → выкл.
    var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }

    var systemImage: String {
        switch self {
        case .off, .all: "repeat"
        case .one: "repeat.1"
        }
    }

    /// Выключенный режим рисуется бледным, включённый — акцентным.
    var isActive: Bool { self != .off }

    /// Подпись для голосового доступа: значок «repeat» сам по себе не говорит,
    /// повторяется очередь или один трек.
    var title: String {
        switch self {
        case .off: "Repeat off"
        case .all: "Repeat queue"
        case .one: "Repeat track"
        }
    }
}
