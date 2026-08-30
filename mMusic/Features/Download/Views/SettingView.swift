import PhotosUI
import SwiftUI
import SwiftData

struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showImagePicker = false
    
    @State private var name = ""
    @State private var artists: [ArtistDraft] = []
    @State private var genre: Genre = .pop
    @State private var artworkData: Data?
    @State private var release = Date()
    @State private var hasReleaseOn = false
    @State private var importError: String?
    /// nil — создать новый сингл; иначе трек добавляется в выбранный альбом.
    @State private var destinationAlbum: Album?
    /// Теги читаются один раз: перезаписывать поля, которые пользователь уже правит, нельзя.
    @State private var didLoadMetadata = false

    @Query(sort: \Album.name) private var albums: [Album]

    let file: PickedFile
    /// Метаданные, добытые не из файла (например, из SoundCloud). Если они есть,
    /// теги самого файла не читаются: у скачанного mp3 их может не быть вовсе.
    let preset: AudioMetadata?
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                Section {
                    VStack {
                        if let artworkData, let uiImage = UIImage(data: artworkData) {
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
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.glassProminent)
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(imageData: $artworkData)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section("name") {
                    TextField("", text: $name)
                }
                Section("artists") {
                    ArtistsEditor(artists: $artists)
                }
                Section {
                    Picker("genre", selection: $genre) {
                        ForEach(Genre.allCases, id: \.self) { genre in
                            Text(genre.rawValue).tag(genre)
                        }
                    }
                }
                Section("album") {
                    Picker("album", selection: $destinationAlbum) {
                        Text("New single").tag(Album?.none)
                        ForEach(albums) { album in
                            Text(album.name).tag(Album?.some(album))
                        }
                    }
                }
                // У существующего альбома свои обложка и дата — трек их наследует.
                if destinationAlbum == nil {
                    Section("release") {
                        Toggle("has release date", isOn: $hasReleaseOn)
                        if hasReleaseOn {
                            DatePicker("release date", selection: $release, displayedComponents: .date)
                        }
                    }
                }
            }
            .navigationTitle("Track settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        save()
                    }
                }
            }
            .task {
                await loadMetadata()
            }
            .alert(
                "Import failed",
                isPresented: Binding(
                    get: { importError != nil },
                    set: { if !$0 { importError = nil } }
                ),
                presenting: importError
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
        }
    }

    /// Поля заполняются разбором имени файла сразу, чтобы форма не открывалась пустой.
    /// Теги из самого файла приходят следом, в `loadMetadata`.
    init(file: PickedFile, preset: AudioMetadata? = nil) {
        self.file = file
        self.preset = preset
        _name = State(initialValue: file.url.parseMusic().name)
        let names = file.url.parsedArtistNames()
        let drafts = names.isEmpty ? [ArtistDraft(name: "unknown")] : names.map { ArtistDraft(name: $0) }
        _artists = State(initialValue: drafts)
    }

    /// Тег точнее имени файла, поэтому он выигрывает — но только там, где он есть.
    private func loadMetadata() async {
        guard !didLoadMetadata else { return }
        didLoadMetadata = true

        let metadata: AudioMetadata
        if let preset {
            metadata = preset
        } else {
            metadata = await AudioMetadata.load(from: file.url)
        }

        if let title = metadata.title { name = title }
        if !metadata.artistNames.isEmpty {
            artists = metadata.artistNames.map { ArtistDraft(name: $0) }
        }
        if let artwork = metadata.artwork, artworkData == nil { artworkData = artwork }

        // Альбом из тега выбираем, только если такой уже есть в библиотеке:
        // создавать его вслепую по названию — верный способ наплодить дубли.
        if let albumName = metadata.albumName,
           let existing = albums.first(where: { $0.name.caseInsensitiveCompare(albumName) == .orderedSame }) {
            destinationAlbum = existing
        }
    }
    
    private func save() {
        // Файл кладём первым: если копирование сорвётся, в базе не останется трека,
        // ссылающегося в пустоту — раньше ошибка просто печаталась в консоль.
        let filename: String
        do {
            filename = try AudioFileStore.importFile(from: file.url)
        } catch {
            importError = error.localizedDescription
            return
        }

        if let album = destinationAlbum {
            addToExisting(album, filename: filename)
        } else {
            createSingle(filename: filename)
        }

        dismiss()
    }

    /// Обычный импорт: трек и одноимённый альбом-сингл, авторство на альбоме.
    private func createSingle(filename: String) {
        let album = Album(name: name, type: .single, release: hasReleaseOn ? release : nil, artwork: artworkData)
        let track = Track(name: name, album: album, credits: [], genre: genre, filename: filename)

        modelContext.insert(album)
        modelContext.insert(track)

        for (position, draft) in artists.enumerated() {
            let artistModel = modelContext.findOrCreateArtist(named: draft.name)
            let credit = Credit(artist: artistModel, role: draft.role, position: position, album: album)

            modelContext.insert(credit)
        }
    }

    /// Трек в существующий альбом. Авторов альбома он наследует, поэтому в его
    /// собственные credits попадают только те, кого в альбоме ещё нет.
    private func addToExisting(_ album: Album, filename: String) {
        let track = Track(name: name, credits: [], genre: genre, filename: filename)
        track.artwork = artworkData

        modelContext.insert(track)
        // Альбом ставит `append`: он же выдаёт номер. Сам по себе трек номера не знает.
        album.append([track])

        let albumArtistNames = album.artistNames

        let extras = artists.filter { draft in
            !albumArtistNames.contains { $0.caseInsensitiveCompare(draft.name) == .orderedSame }
        }

        for (position, draft) in extras.enumerated() {
            let artistModel = modelContext.findOrCreateArtist(named: draft.name)
            let credit = Credit(artist: artistModel, role: .featured, position: position, track: track)

            modelContext.insert(credit)
        }
    }

}
