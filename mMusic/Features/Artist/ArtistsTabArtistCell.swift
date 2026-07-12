import SwiftData
import SwiftUI

struct ArtistsTabArtistCell: View {
    
    @Environment(\.modelContext) private var modelContext

    @State private var showDeleteConfirmation = false

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
                    showDeleteConfirmation = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Remove \"\(artist.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                modelContext.delete(artist)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This artist will be permanently deleted.")
        }
    }
}
