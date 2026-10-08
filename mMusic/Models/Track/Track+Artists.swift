import Foundation
import SwiftData

extension Track {

    /// Авторы трека с ролями, как их видно в списках: сначала авторы альбома,
    /// потом свои отметки трека, без повторов по имени — так же, как `artists`.
    /// Из этого списка редактор начинает, когда трек правят в чужой форме.
    var artistDrafts: [ArtistDraft] {
        let inherited = album?.credits.sorted { $0.position < $1.position } ?? []
        let own = credits.sorted { $0.position < $1.position }

        var seen = Set<String>()
        return (inherited + own).compactMap { credit in
            guard seen.insert(credit.artist.name).inserted else { return nil }
            return ArtistDraft(name: credit.artist.name, role: credit.role)
        }
    }

    /// Свои отметки трека — заново по списку из редактора. Авторов альбома
    /// из списка пропускаем: их трек и так наследует от альбома, а отметка
    /// на самом треке задвоила бы их на странице артиста.
    func setOwnArtists(_ drafts: [ArtistDraft], albumArtists: [String], in context: ModelContext) {
        for credit in Array(credits) {
            context.delete(credit)
        }

        let own = drafts.filter { draft in
            !albumArtists.contains { $0.caseInsensitiveCompare(draft.name) == .orderedSame }
        }

        for (position, draft) in own.enumerated() {
            let artist = context.findOrCreateArtist(named: draft.name)
            context.insert(Credit(artist: artist, role: draft.role, position: position, track: self))
        }
    }
}
