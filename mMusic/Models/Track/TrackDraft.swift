import Foundation
import SwiftData

struct TrackDraft: Identifiable {
    let id = UUID()
    var name: String
    var genre: Genre = .pop
    var artists: [ArtistDraft] = []
    var stagedURL: URL
    /// Файл в «Файлах», из которого сделан черновик. Нужен, чтобы убрать оригинал
    /// после сохранения альбома — но не раньше: создание можно и отменить.
    var originalURL: URL?
    var sourceTrack: PersistentIdentifier?
    /// На какой пластинке будущего альбома лежит трек. nil — только что добавлен
    /// и ещё не разложен: такой ложится на последнюю пластинку.
    var disc: Int?
}
