import SwiftUI

struct ArtistsTabArtistCell: View {
    
    var artist: Artist
    
    var body: some View {
        NavigationLink {
            ArtistView(artist: artist)
        } label: {
            HStack {
                Circle()
                    .overlay {
                        Image(systemName: "music.note")
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(width: 70, height: 70)
                Text(artist.name)
            }
        }
    }
}
