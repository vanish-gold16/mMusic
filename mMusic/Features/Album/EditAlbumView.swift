import SwiftUI

struct EditAlbumView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker = false

    @Bindable var album: Album

    private var hasRelease: Binding<Bool> {
        Binding(
            get: { album.release != nil },
            set: { album.release = $0 ? .now : nil }
        )
    }
    private var releaseDate: Binding<Date> {
        Binding(
            get: { album.release ?? .now },
            set: { album.release = $0 }
        )
    }

    private var sortedTracks: [Track] {
        album.tracks.sorted { $0.position < $1.position }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if let artworkData = album.artwork, let uiImage = UIImage(data: artworkData) {
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
                            ImagePicker(imageData: $album.artwork)
                        }
                    }
                }

                Section("album name") {
                    TextField(album.name, text: $album.name)
                }

                Picker("type", selection: $album.type) {
                    ForEach(Album.AlbumType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                Section("release") {
                    Toggle("has release date", isOn: hasRelease)
                    if album.release != nil {
                        DatePicker("release date", selection: releaseDate, displayedComponents: .date)
                    }
                }

                if !sortedTracks.isEmpty {
                    Section("tracks") {
                        ForEach(sortedTracks) { track in
                            TrackCell(track: track, leadingStyle: .artwork)
                        }
                    }
                }
            }
            .navigationTitle("Edit album")
            .navigationBarTitleDisplayMode(.inline)
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
