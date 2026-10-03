import SwiftData
import SwiftUI

/// То, как плейлист выглядит снаружи: веер обложек и строка-паспорт. Общее
/// у экрана плейлиста и строки в библиотеке — иначе они разошлись бы на первой же правке.
extension Playlist {

    /// Из чего собирать веер: своя обложка плейлиста, затем обложки треков —
    /// по одной на альбом, иначе три карты подряд оказались бы одной картинкой.
    var fanCovers: [Data] {
        var sources: [Data] = []
        if let artwork { sources.append(artwork) }

        var seenAlbums = Set<PersistentIdentifier>()
        for track in orderedTracks where sources.count < 3 {
            guard let data = track.displayArtwork else { continue }

            if let album = track.album, album.artwork != nil,
               !seenAlbums.insert(album.persistentModelID).inserted {
                continue
            }
            sources.append(data)
        }

        return sources
    }

    /// Паспорт одной строкой: «11 TRACKS · 45 MIN · 5 ARTISTS». Артисты — только
    /// на экране плейлиста: в строке библиотеки места на них нет.
    func summary(includingArtists: Bool) -> String {
        let tracks = orderedTracks
        guard !tracks.isEmpty else { return "NO TRACKS YET" }

        var parts = [tracks.count == 1 ? "1 track" : "\(tracks.count) tracks"]

        // Складывается из уже прочитанных длительностей — файлы для этого не открываются.
        let minutes = Int((tracks.reduce(0) { $0 + $1.duration } / 60).rounded())
        if minutes > 0 {
            parts.append(minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min")
        }

        if includingArtists {
            let artists = Set(tracks.flatMap(\.artistNames)).count
            if artists > 0 {
                parts.append(artists == 1 ? "1 artist" : "\(artists) artists")
            }
        }

        return parts.joined(separator: "  ·  ").uppercased()
    }
}

extension AudioPlayer {

    /// Очередь собрана из этих треков: в ней все они, и играет один из них.
    /// Лишние треки в очереди не мешают — их могли добавить через «Play next».
    ///
    /// Одного «играет трек из плейлиста» мало: песня может лежать в пяти
    /// плейлистах сразу, а запущен из них один.
    func isQueue(from tracks: [Track]) -> Bool {
        guard let current = currentTrack, !tracks.isEmpty else { return false }

        let ids = Set(tracks.map(\.id))
        guard ids.contains(current.id) else { return false }

        return ids.isSubset(of: Set(queue.map(\.id)))
    }
}
