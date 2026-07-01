import SwiftUI

struct EditTrackView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable private var track: Track
    
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    if let artworkData = track.artwork, let uiImage = UIImage(data: artworkData) {
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
                        TextField(track.artist, text: $track.artist)
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
                            dismiss()
                        }
                    }
                }
                .padding(.top)
            }
        }
    }
}
