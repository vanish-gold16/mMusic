import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct EditAlbumView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker = false
    @State private var showTrackPicker = false
    @State private var isImporting = false
    @State private var showSoundCloud = false
    @State private var addedTracks: [TrackDraft] = []
    /// Файлы, которые не удалось положить в библиотеку. Пустой список — всё прошло.
    @State private var failedImports: [String] = []

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

                VStack {
                    HStack(spacing: 16) {
                        Button {
                            isImporting = true
                        } label: {
                            VStack {
                                Text("Upload music")
                                Image(systemName: "square.and.arrow.down")
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 15))
                        .tint(.blue)
                        Button {

                        } label: {
                            VStack {
                                Text("From YouTube")
                                Image(systemName: "video")
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 15))
                        .tint(.red)
                    }
                    Button {
                        showSoundCloud = true
                    } label: {
                        VStack {
                            Text("SoundCloud")
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 15))
                .padding(.top)
                .tint(.orange)
                .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: [.audio],
                    allowsMultipleSelection: true,
                    onCompletion: handleFileLoading
                )
                .sheet(isPresented: $showSoundCloud) {
                    SoundCloudImportView { file, metadata in
                        addTrack(from: file, metadata: metadata)
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
            .alert(
                "Some files were not imported",
                isPresented: Binding(
                    get: { !failedImports.isEmpty },
                    set: { if !$0 { failedImports = [] } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(failedImports.joined(separator: "\n"))
            }
        }
    }

    /// Импортирует выбранные аудиофайлы в альбом, создавая треки и добавляя их в конец списка.
    private func handleFileLoading(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let base = album.tracks.count
            let albumArtistNames = album.artists.map(\.name)
            var imported: [Track] = []

            for (offset, url) in urls.enumerated() {
                let filename: String
                do {
                    filename = try AudioFileStore.importFile(from: url)
                } catch {
                    failedImports.append(url.lastPathComponent)
                    continue
                }

                let track = Track(name: url.parseMusic().name, album: album, credits: [], genre: .pop, filename: filename)
                track.position = base + offset

                modelContext.insert(track)
                imported.append(track)

                let names = url.parsedArtistNames().filter { name in
                    !albumArtistNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
                }

                for (position, name) in names.enumerated() {
                    let artistModel = modelContext.findOrCreateArtist(named: name)
                    let credit = Credit(artist: artistModel, role: .featured, position: position, track: track)

                    modelContext.insert(credit)
                }
            }

            Task { await applyMetadata(to: imported) }
        case .failure(let error):
            failedImports.append(error.localizedDescription)
        }
    }

    /// Читается уже из скопированного файла: доступ к исходному URL короткоживущий.
    /// Артистов не трогаем — их credits уже созданы, и правит их пользователь в редакторе.
    private func applyMetadata(to tracks: [Track]) async {
        for track in tracks {
            let metadata = await AudioMetadata.load(from: AudioFileStore.url(for: track.filename))

            if let title = metadata.title { track.name = title }
            if let artwork = metadata.artwork, track.artwork == nil { track.artwork = artwork }
        }
    }

    /// Трек с SoundCloud: файл уже во временной папке, поэтому его переносим, а не копируем.
    private func addTrack(from file: PickedFile, metadata: AudioMetadata) {
        let filename: String
        do {
            filename = try AudioFileStore.moveIntoLibrary(from: file.url)
        } catch {
            failedImports.append(metadata.title ?? file.url.lastPathComponent)
            return
        }

        let track = Track(
            name: metadata.title ?? file.url.parseMusic().name,
            album: album,
            credits: [],
            genre: .pop,
            filename: filename,
            artwork: metadata.artwork
        )
        track.position = album.tracks.count

        modelContext.insert(track)

        let albumArtistNames = album.artists.map(\.name)
        let names = metadata.artistNames.filter { name in
            !albumArtistNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        }

        for (position, name) in names.enumerated() {
            let artistModel = modelContext.findOrCreateArtist(named: name)
            modelContext.insert(Credit(artist: artistModel, role: .featured, position: position, track: track))
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
                stagedURL: AudioFileStore.url(for: track.filename),
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
