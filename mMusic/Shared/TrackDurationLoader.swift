import AVFoundation
import Foundation

/// Дочитывает длительность треков из самих файлов.
///
/// Раньше `PlaylistView` вскрывал `AVURLAsset` по всем файлам плейлиста каждый раз,
/// когда его открывали. Теперь длительность живёт в `Track.duration`, а сюда попадают
/// только те треки, у которых её ещё нет.
enum TrackDurationLoader {

    /// Заполняет длительность по одному треку за раз: файлов может быть много,
    /// а спешить некуда — экран уже показан.
    static func fill(_ tracks: [Track]) async {
        for track in tracks {
            guard !Task.isCancelled else { return }

            let asset = AVURLAsset(url: AudioFileStore.url(for: track.filename))

            // Файла может не быть — тогда просто идём дальше: 0 останется 0,
            // и следующая попытка случится при следующем запуске.
            guard let duration = try? await asset.load(.duration) else { continue }

            let seconds = CMTimeGetSeconds(duration)
            guard seconds.isFinite, seconds > 0 else { continue }

            track.duration = seconds

            // Та же передышка, что и у волны: после восстановления библиотеки
            // сюда попадают все треки разом, а играющая музыка важнее.
            try? await Task.sleep(for: .milliseconds(60))
        }
    }
}
