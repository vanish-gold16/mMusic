import SwiftUI

struct EditPlaylistView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showImagePicker = false
    
    @Bindable var playlist: Playlist
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if let artworkData = playlist.artwork, let uiImage = UIImage(data: artworkData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .overlay {
                                    Image(systemName: "music.note")
                                }
                                .scaledToFit()
                                .frame(height: 150)
                        }
                        
                        Spacer()
                        
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("Pick an image", systemImage: "photo")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.glassProminent)
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(imageData: $playlist.artwork)
                        }
                    }
                }
                
                Section("playlist name") {
                    TextField(playlist.name, text: $playlist.name)
                }
                Section("description") {
                    TextField(playlist.playlistDescription, text: $playlist.playlistDescription)
                }
                
                if !playlist.tracks.isEmpty {
                    ForEach(playlist.tracks) { track in
                        TrackCell(track: track, leadingStyle: .artwork)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
