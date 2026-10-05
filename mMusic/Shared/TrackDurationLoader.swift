import AVFoundation
import Foundation
import SwiftData

/// Дочитывает длительность треков из самих файлов.
///
/// Раньше `PlaylistView` вскрывал `AVURLAsset` по всем файлам плейлиста каждый раз,
/// когда его открывали. Теперь длительность живёт в `Track.duration`, а сюда попадают
/// только те треки, у которых её ещё нет.
enum TrackDurationLoader {

    /// Длительность файла, которого ещё нет в библиотеке, — для превью в формах
    /// импорта. nil — не прочиталась. Доступ security-scoped: файл может лежать
    /// в «Файлах», куда без него не пускают.
    static func duration(of url: URL) async -> TimeInterval? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        return await measure(url)
    }

    /// Заполняет длительность по одному треку за раз: файлов может быть много,
    /// а спешить некуда — экран уже показан.
    static func fill(_ tracks: [Track]) async {
        for track in tracks {
            guard !Task.isCancelled else { return }

            // Файла может не быть — тогда просто идём дальше: 0 останется 0,
            // и следующая попытка случится при следующем запуске.
            guard let seconds = await measure(AudioFileStore.url(for: track.filename)) else { continue }

            track.duration = seconds

            // Та же передышка, что и у волны: после восстановления библиотеки
            // сюда попадают все треки разом, а играющая музыка важнее.
            try? await Task.sleep(for: .milliseconds(60))
        }
    }

    /// Разовая перемерка длительностей, прочитанных старым способом.
    ///
    /// Раньше длина бралась у `AVURLAsset`, и у фрагментированных m4a (так
    /// приходят дорожки с YouTube) она выходила ровно вдвое больше настоящей —
    /// в альбоме 9:02 у трека, который играет 4:31. Перемерять надо только один
    /// раз: всё, что импортируется дальше, уже меряется правильно. Пишем лишь
    /// там, где длина разошлась больше чем на секунду, остальное не трогаем.
    static func remeasureOnce(in context: ModelContext) async {
        let key = "durationsRemeasuredByAudioFile"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let tracks = (try? context.fetch(FetchDescriptor<Track>(predicate: #Predicate { $0.duration > 0 }))) ?? []
        for track in tracks {
            guard !Task.isCancelled else { return }

            if let seconds = await measure(AudioFileStore.url(for: track.filename)),
               abs(seconds - track.duration) > 1 {
                track.duration = seconds
            }

            // Файл открывается за доли миллисекунды, но их сотни, а это главный
            // поток — отдаём его интерфейсу между файлами.
            await Task.yield()
        }

        UserDefaults.standard.set(true, forKey: key)
    }

    /// Длина записи так, как её сыграет плеер.
    ///
    /// `AVAudioFile` — тот же файл, что открывает `PlaybackEngine`, и та же формула:
    /// кадры звука, делённые на частоту. `AVURLAsset` же верит заголовку контейнера,
    /// а у фрагментированного m4a в заголовке уже записана полная длина, и он
    /// прибавляет к ней длину фрагмента ещё раз.
    private static func measure(_ url: URL) async -> TimeInterval? {
        if let file = try? AVAudioFile(forReading: url), file.processingFormat.sampleRate > 0 {
            let seconds = Double(file.length) / file.processingFormat.sampleRate
            if seconds > 0 { return seconds }
        }

        // AudioToolbox не открывает файл, у которого расширение не совпадает
        // с содержимым (m4a под именем .mp3). Играть такой плеер тоже не сможет,
        // но длину покажем хотя бы по заголовку.
        guard let time = try? await AVURLAsset(url: url).load(.duration) else { return nil }

        let seconds = CMTimeGetSeconds(time)
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }
}
