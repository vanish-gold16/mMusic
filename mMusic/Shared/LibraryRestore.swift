import Foundation
import SwiftData

/// Сборка треков заново по файлам в Documents.
///
/// Файл и запись о нём в базе — разные вещи, и файл вполне может пережить запись.
/// Тогда трек собирается обратно: сперва по истории прослушиваний — `PlayEvent`
/// дублирует название, артистов, альбом и жанр как раз на такой случай, — а если
/// истории нет, по тегам самого файла и его имени.
///
/// Восстановить нельзя только то, чего нет ни там, ни там: состав плейлистов,
/// избранное и собственные обложки треков.
enum LibraryRestore {

    struct Result {
        /// Сколько треков вернулось в библиотеку.
        var restored = 0
        /// Из них — собранных по истории, то есть с прежним названием и артистами.
        var fromHistory = 0
    }

    private static let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "aac", "flac", "aiff", "aif", "alac", "caf"]

    /// Аудиофайлы, на которые не ссылается ни один трек.
    static func orphanFiles(known: Set<String>) -> [String] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: URL.documentsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []

        return contents
            .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            .map(\.lastPathComponent)
            .filter { !known.contains($0) }
            .sorted()
    }

    /// Возвращает файлы в библиотеку. Альбом подхватывается только существующий:
    /// плодить пустые альбомы по названию из тега — хуже, чем оставить трек без него.
    @MainActor
    static func restore(_ filenames: [String], in context: ModelContext) async -> Result {
        let history = historyByFile(in: context)
        var result = Result()

        for filename in filenames {
            let url = AudioFileStore.url(for: filename)
            let events = history[filename] ?? []

            // История главнее тегов: в ней лежит то, как трек был назван в самой
            // библиотеке, вместе со всеми правками имени и состава артистов.
            let restored: Track
            if let latest = events.max(by: { $0.playedAt < $1.playedAt }) {
                restored = Track(
                    name: latest.trackName,
                    credits: [],
                    genre: latest.genre,
                    filename: filename
                )
                result.fromHistory += 1
            } else {
                let metadata = await AudioMetadata.load(from: url)
                let parsed = url.parseMusic()

                restored = Track(
                    name: metadata.title ?? parsed.name,
                    credits: [],
                    genre: .pop,
                    filename: filename
                )
                if let artwork = metadata.artwork { restored.artwork = artwork }
            }

            context.insert(restored)

            // «В библиотеке с» — дата появления файла на диске: именно тогда трек
            // и был импортирован. Иначе все годовщины съехали бы на сегодня.
            restored.addedAt = creationDate(of: url) ?? .now

            if !events.isEmpty {
                restored.playCount = events.count
                restored.lastPlayedAt = events.map(\.playedAt).max()
            }

            attachArtists(to: restored, events: events, url: url, in: context)
            attachAlbum(to: restored, name: events.first?.albumName, in: context)

            result.restored += 1
        }

        return result
    }

    /// Вся история одним проходом: отдельный запрос на файл обошёлся бы в сотни выборок.
    private static func historyByFile(in context: ModelContext) -> [String: [PlayEvent]] {
        let events = (try? context.fetch(FetchDescriptor<PlayEvent>())) ?? []

        return events.reduce(into: [:]) { grouped, event in
            grouped[event.trackFilename, default: []].append(event)
        }
    }

    private static func attachArtists(
        to track: Track,
        events: [PlayEvent],
        url: URL,
        in context: ModelContext
    ) {
        // Имена из истории уже разобраны на отдельных артистов; из имени файла —
        // как получится, но это лучше, чем ничего.
        let names = events.max(by: { $0.playedAt < $1.playedAt })?.artistNames
            ?? url.parsedArtistNames()

        for (position, name) in names.enumerated() {
            let artist = context.findOrCreateArtist(named: name)
            context.insert(Credit(artist: artist, role: .main, position: position, track: track))
        }
    }

    /// Альбом только существующий: сам он удаление треков пережил, и трек
    /// возвращается на своё место в нём.
    private static func attachAlbum(to track: Track, name: String?, in context: ModelContext) {
        guard let name else { return }

        let descriptor = FetchDescriptor<Album>(predicate: #Predicate { $0.name == name })
        guard let album = try? context.fetch(descriptor).first else { return }

        track.album = album
        track.position = album.tracks.count
    }

    private static func creationDate(of url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.creationDate] as? Date
    }
}
