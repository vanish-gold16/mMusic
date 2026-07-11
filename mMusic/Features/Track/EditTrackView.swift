import SwiftData
import SwiftUI

struct EditTrackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var track: Track
    
    @State private var showImagePicker = false
    
    @State private var drafts: [ArtistDraft] = []
    
    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    if let artworkData = track.displayArtwork, let uiImage = UIImage(data: artworkData) {
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
                    
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("Pick an image", systemImage: "photo")
                    }
                    .buttonStyle(.glassProminent)
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(imageData: $track.artwork)
                    }
                }
                
                Form {
                    Section("name") {
                        TextField(track.name, text: $track.name)
                    }
                    Section("artist") {
                        ArtistsEditor(
                            artists: $drafts,
                            readOnlyArtists: track.album?.artists.map(\.name) ?? []
                        )
                    }
                    Section() {
                        Picker("genre", selection: $track.genre) {
                            ForEach(Genre.allCases, id: \.self) { genre in
                                Text(genre.rawValue).tag(genre)
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("done") {
                            syncArtists()
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    drafts = track.credits
                        .sorted { $0.position < $1.position }
                        .map { ArtistDraft(name: $0.artist.name, role: $0.role) }
                }
                .padding(.top)
            }
        }
    }
    
    private func syncArtists() {
        for credit in Array(track.credits) {
            modelContext.delete(credit)
        }
        for(position, draft) in drafts.enumerated() {
            let artist = modelContext.findOrCreateArtist(named: draft.name)
            let credit = Credit(artist: artist, role: draft.role, position: position, track: track)
            modelContext.insert(credit)
        }
    }
    
}
