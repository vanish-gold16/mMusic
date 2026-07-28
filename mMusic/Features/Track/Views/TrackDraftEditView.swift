import SwiftUI

struct TrackDraftEditView: View {
    
    @Binding var draft: TrackDraft
    
    var albumArtists: [String] = []
    
    var body: some View {
        Form {
            Section("name") {
                TextField(draft.name, text: $draft.name)
            }
            Section {
                Picker("genre", selection: $draft.genre) {
                    ForEach(Genre.allCases, id: \.self) { genre in
                        Text(genre.rawValue).tag(genre)
                    }
                }
            }
            Section("artists") {
                ArtistsEditor(artists: $draft.artists, readOnlyArtists: albumArtists)
            }
        }
        .navigationTitle(draft.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
