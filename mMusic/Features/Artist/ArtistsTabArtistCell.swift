import SwiftData
import SwiftUI

struct ArtistsTabArtistCell: View {
    
    @Environment(\.modelContext) private var modelContext
    
    var artist: Artist
    
    var body: some View {
        NavigationLink {
            ArtistView(artist: artist)
        } label: {
            HStack {
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .frame(width: 70, height: 70)
                    .background(Color.gray.opacity(0.2), in: Circle())
                Text(artist.name)
                Spacer()
            }
        }
        .contextMenu {
            VStack {
                Button {
                    
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    modelContext.delete(artist)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }
}
