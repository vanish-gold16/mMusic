import SwiftUI

struct ArtistView: View {
    
    var artist: Artist
    
    var body: some View {
        Text(artist.name)
    }
}
