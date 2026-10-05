import Foundation
import SwiftData

/// Пластинки артиста, разложенные по полкам: его альбомы, его синглы и EP
/// и чужие пластинки, где он гость.
///
/// Своё — то, где артист стоит в авторах альбома основным, со звездой.
/// Всё остальное, где он есть, — гостевое: в авторах альбома без звезды
/// или только на отдельных треках чужой пластинки. Звезда на отдельном треке
/// пластинку своей не делает: альбом от этого остаётся чужим.
struct ArtistDiscography {

    /// Свои LP.
    let albums: [Album]
    /// Свои синглы и EP — короткое, что выходит между альбомами.
    let singles: [Album]
    /// Чужие пластинки, где артист в гостях.
    let featuredOn: [Album]

    /// Чужие пластинки, где артист в авторах всего альбома, а не отдельных треков.
    private let wholeAlbumGuests: Set<PersistentIdentifier>
    /// Треки чужих пластинок, где артист отмечен лично.
    private let guestCredits: [PersistentIdentifier: [Track]]

    init(artist: Artist) {
        var own: [Album] = []
        var ownIDs = Set<PersistentIdentifier>()
        var guests: [Album] = []
        var guestIDs = Set<PersistentIdentifier>()
        var wholeAlbumGuests = Set<PersistentIdentifier>()
        var guestCredits: [PersistentIdentifier: [Track]] = [:]

        let albumCredits = artist.credits.filter { $0.album != nil }

        // Сначала звёзды: если артист записан в авторы альбома дважды,
        // основным и гостем, альбом всё равно его.
        for credit in albumCredits where credit.role == .main {
            guard let album = credit.album, ownIDs.insert(album.persistentModelID).inserted else { continue }
            own.append(album)
        }

        for credit in albumCredits where credit.role == .featured {
            guard let album = credit.album, !ownIDs.contains(album.persistentModelID) else { continue }
            wholeAlbumGuests.insert(album.persistentModelID)
            if guestIDs.insert(album.persistentModelID).inserted { guests.append(album) }
        }

        // Отметка на треке своего альбома ничего не добавляет: альбом и так его.
        for credit in artist.credits {
            guard let track = credit.track, let album = track.album else { continue }
            let id = album.persistentModelID
            guard !ownIDs.contains(id) else { continue }

            if guestIDs.insert(id).inserted { guests.append(album) }
            guestCredits[id, default: []].append(track)
        }

        albums = Self.chronological(own.filter { $0.type == .LP })
        singles = Self.chronological(own.filter { $0.type != .LP })
        featuredOn = Self.chronological(guests)
        self.wholeAlbumGuests = wholeAlbumGuests
        self.guestCredits = guestCredits
    }

    /// Свои пластинки от первой к последней — в таком порядке они лежат
    /// кольцами на пластинке артиста. Если своих нет, там гостевые:
    /// пустой диск ничего бы о нём не сказал.
    var career: [Album] {
        let own = albums + singles
        return own.isEmpty ? featuredOn : Self.chronological(own)
    }

    /// Где на чужой пластинке звучит артист, в порядке альбома. Гость всего
    /// альбома звучит на всех треках.
    func guestTracks(on album: Album) -> [Track] {
        let id = album.persistentModelID
        let tracks = wholeAlbumGuests.contains(id) ? album.tracks : guestCredits[id] ?? []

        var seen = Set<PersistentIdentifier>()
        return tracks
            .filter { seen.insert($0.persistentModelID).inserted }
            .sorted { $0.position < $1.position }
    }

    var isEmpty: Bool {
        albums.isEmpty && singles.isEmpty && featuredOn.isEmpty
    }

    /// По дате выхода, от старых к новым — дискография читается как история.
    /// Без даты — в конце, а между собой по дате добавления: иначе их порядок
    /// менялся бы от раза к разу.
    private static func chronological(_ albums: [Album]) -> [Album] {
        albums.sorted { isEarlier($0, than: $1) }
    }

    private static func isEarlier(_ left: Album, than right: Album) -> Bool {
        switch (left.release, right.release) {
        case let (leftRelease?, rightRelease?) where leftRelease != rightRelease:
            leftRelease < rightRelease
        case (_?, nil):
            true
        case (nil, _?):
            false
        default:
            left.addedAt < right.addedAt
        }
    }
}
