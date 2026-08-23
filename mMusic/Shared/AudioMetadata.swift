import AVFoundation
import Foundation

/// Теги, зашитые в сам аудиофайл. До этого имя трека и артист выдирались только
/// из имени файла — а там их может не быть вовсе.
struct AudioMetadata {
    var title: String?
    var artist: String?
    var albumName: String?
    var artwork: Data?

    /// Пустые строки приравниваются к отсутствию: тег бывает записан, но пуст,
    /// и подставлять его вместо разбора имени файла нельзя.
    static func load(from url: URL) async -> AudioMetadata {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else { return AudioMetadata() }

        var metadata = AudioMetadata()

        for item in items {
            switch item.commonKey {
            case .commonKeyTitle:
                metadata.title = await string(from: item)
            case .commonKeyArtist, .commonKeyAuthor:
                // `??` не годится: его правая часть — autoclosure, а там await запрещён.
                if metadata.artist == nil { metadata.artist = await string(from: item) }
            case .commonKeyAlbumName:
                metadata.albumName = await string(from: item)
            case .commonKeyArtwork:
                metadata.artwork = try? await item.load(.dataValue)
            default:
                break
            }
        }

        // Общие ключи покрывают не все файлы: в части mp3 альбом записан только
        // в родном ID3-теге, а в m4a — в iTunes-овском. Для названия и артиста это
        // не так важно (их видно по имени файла), а вот альбом больше взять неоткуда.
        if metadata.albumName == nil {
            metadata.albumName = await albumFromFormatTags(of: asset)
        }

        return metadata
    }

    /// Альбом из тегов конкретного формата — там, где общий ключ пуст.
    private static func albumFromFormatTags(of asset: AVURLAsset) async -> String? {
        guard let items = try? await asset.load(.metadata) else { return nil }

        let identifiers: [AVMetadataIdentifier] = [
            .id3MetadataAlbumTitle,
            .iTunesMetadataAlbum,
            .quickTimeMetadataAlbum
        ]

        for identifier in identifiers {
            let matching = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier)
            for item in matching {
                if let value = await string(from: item) { return value }
            }
        }

        return nil
    }

    private static func string(from item: AVMetadataItem) async -> String? {
        guard let value = try? await item.load(.stringValue) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Артистов в теге часто пишут через запятую, косую черту или «feat.».
    var artistNames: [String] {
        guard let artist else { return [] }

        return artist
            .components(separatedBy: CharacterSet(charactersIn: ",/&"))
            .flatMap { $0.components(separatedBy: " feat. ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
