import SwiftUI

/// Трек внутри собираемого альбома: имя крупно в шапке, авторы и жанр —
/// разделами, как в форме нового трека. Авторы альбома стоят приглушёнными
/// впереди: они у трека и так есть, здесь добавляют только гостей.
struct TrackDraftEditView: View {

    @Binding var draft: TrackDraft

    var albumArtists: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RecordTitleField(placeholder: "Track name", text: $draft.name)
                    .padding(.horizontal)

                RecordFormSection("Artists") {
                    VStack(alignment: .leading, spacing: 10) {
                        ArtistsEditor(artists: $draft.artists, readOnlyArtists: albumArtists)
                        RecordHint("Tap a name to mark a guest")
                    }
                    .padding(.horizontal)
                }

                RecordFormSection("Genre") {
                    GenreMenu(genre: $draft.genre)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
    }
}
