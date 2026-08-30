import Foundation
import SwiftData

/// Сколько времени провели с артистом — свод по истории прослушиваний.
///
/// История намеренно не ссылается на модели: `PlayEvent` хранит имена артистов и
/// имя файла на момент прослушивания. Поэтому событие засчитывается артисту по
/// двум признакам сразу — по имени, чтобы время пережило удаление трека из
/// библиотеки, и по файлу, чтобы старые прослушивания достались артисту, которого
/// вписали в авторы уже потом.
struct ArtistListening {

    /// Реально прослушанные секунды, а не сумма длительностей треков.
    let seconds: TimeInterval
    let plays: Int
    /// Первое прослушивание: с него отсчитывается, сколько вы уже вместе.
    let firstPlayedAt: Date?

    /// Округление до ближайшей минуты, но не в ноль: прослушиванием считается уже
    /// полминуты звука, и «0 min» о нём соврало бы.
    var minutes: Int {
        guard seconds > 0 else { return 0 }
        return max(1, Int((seconds / 60).rounded()))
    }

    /// «3 h 12 min» — появляется, только когда часы действительно есть.
    var hoursAndMinutes: String? {
        guard minutes >= 60 else { return nil }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    static func make(
        for artistName: String,
        filenames: Set<String>,
        from events: [PlayEvent]
    ) -> ArtistListening {
        var seconds: TimeInterval = 0
        var plays = 0
        var first: Date?

        for event in events
        where event.artistNames.contains(artistName) || filenames.contains(event.trackFilename) {
            seconds += event.seconds
            plays += 1
            first = min(first ?? event.playedAt, event.playedAt)
        }

        return ArtistListening(seconds: seconds, plays: plays, firstPlayedAt: first)
    }

    /// Тот же счёт, но история берётся из базы одним запросом: отдельная выборка
    /// на каждое событие обошлась бы дороже, чем прочитать их все разом.
    static func make(
        for artistName: String,
        filenames: Set<String>,
        in context: ModelContext
    ) -> ArtistListening {
        let events = (try? context.fetch(FetchDescriptor<PlayEvent>())) ?? []

        return make(for: artistName, filenames: filenames, from: events)
    }
}
