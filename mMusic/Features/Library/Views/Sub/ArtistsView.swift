import SwiftData
import SwiftUI

struct ArtistsView: View {
    
    @Query private var artists: [Artist]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(artists) { artist in
                    ArtistsTabArtistCell(artist: artist)
                }
            }
        }
    }
}
