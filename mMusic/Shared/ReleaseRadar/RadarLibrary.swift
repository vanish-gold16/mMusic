import Foundation
import SwiftData

/// Библиотека глазами радара: кто в ней есть и какие у них песни.
///
/// Считается все, у кого есть хоть один трек, — и главные, и гости: в библиотеке
/// лежит только то, что слушают, значит, и гость в ней не случайный.
/// Артисты без треков остаются в базе после удаления последнего трека —
/// их радар не видит.
enum RadarLibrary {

    static func snapshot(in context: ModelContext) -> [LibraryArtist] {
        let artists = (try? context.fetch(FetchDescriptor<Artist>())) ?? []

        // По ключу, а не по имени: «КИНО» и «Кино», «AVA MAX» и «Ava Max» —
        // два артиста в базе, но один человек, и уведомление о нём должно
        // прийти одно.
        var grouped: [String: (name: String, titles: [String], weight: Int)] = [:]

        for artist in artists where !artist.credits.isEmpty {
            let key = RadarText.key(artist.name)
            guard !key.isEmpty else { continue }

            var titles: [String] = []
            var weight = 0

            for credit in artist.credits {
                if let track = credit.track {
                    titles.append(track.name)
                    weight += 1 + track.playCount
                }
                if let album = credit.album {
                    titles.append(album.name)
                    for track in album.tracklist {
                        titles.append(track.name)
                        weight += 1 + track.playCount
                    }
                }
            }

            var group = grouped[key] ?? (name: RadarText.query(artist.name), titles: [], weight: 0)
            group.titles += titles
            group.weight += weight
            grouped[key] = group
        }

        return grouped.map { key, group in
            LibraryArtist(
                key: key,
                name: group.name,
                titleKeys: group.titles.reduce(into: Set<String>()) { $0.formUnion(RadarText.titleKeys($1)) },
                ownedKeys: Set(group.titles.map(RadarText.releaseKey)),
                // Своё имя в названии («Krewella - Alive») — не название песни.
                searchTitles: Array(group.titles.flatMap(RadarText.variants).reduce(into: [String]()) { list, title in
                    if RadarText.key(title) != key, !list.contains(title) { list.append(title) }
                }.prefix(8)),
                weight: group.weight
            )
        }
    }
}
