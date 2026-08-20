import SwiftData
import SwiftUI

struct ArtistsSection: View {

    @Query(sort: \Artist.name) private var artists: [Artist]

    var body: some View {
        if artists.isEmpty {
            LibraryEmptyState(text: "No artists yet")
        } else {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(artists) { artist in
                    ArtistsTabArtistCell(artist: artist)
                }
            }
            .padding(.horizontal)
        }
    }
}
