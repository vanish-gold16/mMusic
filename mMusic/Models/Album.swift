import Foundation
import SwiftData

@Model
class Album {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Track.album)
    var tracks: [Track]
    var type: AlbumType
    @Relationship(deleteRule: .cascade, inverse: \Credit.album)
    var credits: [Credit]
    var artists: [Artist] {
        credits.sorted { $0.position < $1.position }
            .map(\.artist)
    }
    var artistNames: [String] {
        artists.map(\.name)
    }
    var genres: [Genre] {
        let counts = tracks.reduce(into: [Genre: Int]()) { counts, track in
            counts[track.genre, default: 0] += 1
        }
        return counts.keys.sorted {
            if counts[$0]! != counts[$1]! {
                return counts[$0]! > counts[$1]!
            }
            return $0.rawValue < $1.rawValue
        }
    }
    var release: Date?
    var isFavourite: Bool = false
    
    var addedAt: Date = Date.now
    
    @Attribute(.externalStorage) var artwork: Data?
    
    init(name: String, tracks: [Track] = [], type: AlbumType, credits: [Credit] = [], release: Date? = nil, artwork: Data? = nil) {
        self.name = name
        self.tracks = tracks
        self.type = type
        self.credits = credits
        self.release = release
        self.artwork = artwork
    }
    
    /// Сплошная нумерация треков с нуля.
    ///
    /// Вызывать после всего, что вынимает трек из середины альбома: удаления из
    /// библиотеки, снятия галочки в пикере, переезда в другой альбом. Иначе в номерах
    /// остаётся дыра (1, 2, 4), а новый трек, которому позицию дают по `tracks.count`,
    /// встаёт на уже занятое место.
    ///
    /// `excluding` — для удаления: пересчитать надо до `delete`, пока ссылка на трек
    /// ещё жива, а считать его при этом уже не нужно.
    func renumberTracks(excluding removed: Track? = nil) {
        let remaining = tracks
            .filter { $0.persistentModelID != removed?.persistentModelID }
            .sorted { $0.position < $1.position }

        for (index, track) in remaining.enumerated() {
            track.position = index
        }
    }

    enum AlbumType: String, Codable, CaseIterable {
        case single = "single"
        case EP = "EP"
        case LP = "LP"
    }
    
}
