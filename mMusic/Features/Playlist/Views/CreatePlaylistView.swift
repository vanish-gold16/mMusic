import SwiftUI
import SwiftData

struct CreatePlaylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showImagePicker = false
    @State private var showTrackPicker = false

    @State private var playlist = Playlist(name: "", tracks: [])
    @State private var artworkData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Group {
                            if let artworkData, let uiImage = UIImage(data: artworkData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                    }
                            }
                        }
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            showImagePicker = true
                        } label: {
                            Label("Pick an image", systemImage: "photo")
                        }
                        .buttonStyle(.glassProminent)
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(imageData: $artworkData)
                        }
                    }
                    .padding(.top)

                    Form {
                        Section("playlist name") {
                            TextField("", text: $playlist.name)
                        }
                        Section("description") {
                            TextField("", text: $playlist.playlistDescription)
                        }
                    }

                    if !playlist.tracks.isEmpty {
                        VStack {
                            ForEach(playlist.tracks) { track in
                                PlaylistTrackCell(track: track)
                            }
                        }
                    }
                    
                    Button {
                        showTrackPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add Music")
                        }
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gray.opacity(0.2), in: Capsule())
                    }
                    .sheet(isPresented: $showTrackPicker) {
                        TrackPickerView(playlist: playlist)
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        create()
                    }
                }
            }
        }
    }

    private func addTrack() {
        
    }

    private func create() {
        playlist.artwork = artworkData
        modelContext.insert(playlist)
        dismiss()
    }
}
