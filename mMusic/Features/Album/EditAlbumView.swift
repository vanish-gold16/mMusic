import SwiftData
import SwiftUI

struct EditAlbumView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker = false
    @State private var showTrackPicker = false
    @State private var addedTracks: [TrackDraft] = []

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
                        .onMove { source, destination in
                            moveTracks(from: source, to: destination)
                        }
                        Button {
                            seedTrackDrafts()
                            showTrackPicker = true
                        } label: {
                            Label("Add Music", systemImage: "plus")
                        }
                    }
                }
            }
            .navigationTitle("Edit album")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTrackPicker, onDismiss: applyTrackDrafts) {
                AlbumTrackPickerView(album: [album], addedTracks: $addedTracks)
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

    /// Меняет порядок треков в альбоме, пересчитывая их позиции.
    private func moveTracks(from: IndexSet, to: Int) {
        var tracks = sortedTracks
        tracks.move(fromOffsets: from, toOffset: to)

        for (index, track) in tracks.enumerated() {
            track.position = index
        }
    }

    /// Заполняет черновики уже добавленными треками, чтобы пикер показывал их выбранными.
    private func seedTrackDrafts() {
        addedTracks = sortedTracks.map { track in
            TrackDraft(
                name: track.name,
                genre: track.genre,
                artists: track.artistNames.map { ArtistDraft(name: $0) },
                stagedURL: URL.documentsDirectory.appending(path: track.filename),
                sourceTrack: track.persistentModelID
            )
        }
    }

    /// Приводит состав альбома в соответствие с выбором в пикере: добавляет выбранные треки и убирает снятые.
    private func applyTrackDrafts() {
        let selectedIDs = Set(addedTracks.compactMap(\.sourceTrack))

        for track in album.tracks where !selectedIDs.contains(track.persistentModelID) {
            track.album = nil
        }

        for (index, draft) in addedTracks.enumerated() {
            guard let id = draft.sourceTrack,
                  let track = modelContext.model(for: id) as? Track else { continue }

            if let previous = track.album, previous.persistentModelID != album.persistentModelID {
                previous.tracks.removeAll { $0.persistentModelID == id }
            }

            track.album = album
            track.position = index
        }
    }
}
