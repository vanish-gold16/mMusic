import Foundation
import SwiftData

/// Одно прослушивание: что, когда и сколько секунд.
///
/// Поля трека продублированы, а ссылки на него нет намеренно. Годовой отчёт должен
/// пережить удаление трека из библиотеки — иначе к декабрю статистика будет тем
/// беднее, чем активнее человек чистил медиатеку.
@Model
final class PlayEvent {
    var playedAt: Date = Date.now
    /// Сколько секунд реально прослушали, а не длина трека.
    var seconds: TimeInterval = 0

    var trackName: String = ""
    /// По нему событие сопоставляется с треком, пока тот ещё в библиотеке.
    var trackFilename: String = ""
    var artistNames: [String] = []
    var albumName: String?
    var genre: Genre = Genre.pop

    init(track: Track, seconds: TimeInterval = 0) {
        self.playedAt = .now
        self.seconds = seconds
        self.trackName = track.name
        self.trackFilename = track.filename
        self.artistNames = track.artistNames
        self.albumName = track.album?.name
        self.genre = track.genre
    }
}
