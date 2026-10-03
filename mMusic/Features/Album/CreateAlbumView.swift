import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct CreateAlbumView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var trackDrafts: [TrackDraft] = []
    @State private var artworkData: Data?
    @State private var artists: [ArtistDraft] = []
    @State private var release: Date?
    @State private var type: Album.AlbumType = .single
    @State private var pickedFile: PickedFile? = nil
    
    @State private var showImagePicker = false
    @State private var showTrackPicker = false
    @State private var isImporting = false
    @State private var showSoundCloud = false
    /// Файлы, которые не удалось положить в библиотеку. Пустой список — всё прошло.
    @State private var failedImports: [String] = []
    /// Названия пластинок будущего альбома. Пусто — пластинка одна.
    @State private var discTitles: [String] = []

    private var discCount: Int { max(discTitles.count, 1) }
    
    private var hasRelease: Binding<Bool> {
        Binding (
            get: { release != nil },
            set: { release = $0 ? .now : nil }
        )
    }
    private var releaseDate: Binding<Date> {
        Binding(
            get: { release ?? .now },
            set: { release = $0 }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.glassProminent)
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(imageData: $artworkData)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
                Section("album name") {
                    TextField("", text: $name)
                }
                Section("artists") {
                    ArtistsEditor(artists: $artists)
                }
                Picker("type", selection: $type) {
                    ForEach(Album.AlbumType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                Section("release") {
                    Toggle("has release date", isOn: hasRelease)
                    if release != nil {
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
                        addDraft(from: file, metadata: metadata)
                    }
                }
                if !trackDrafts.isEmpty || discCount > 1 {
                    Section {
                        tracksEditor
                    } header: {
                        HStack {
                            Text("tracks")
                            Spacer()
                            EditButton()
                        }
                    } footer: {
                        if discCount > 1 {
                            Text("Drag a disc row to change where that disc starts. Deleting it moves its tracks to the previous disc.")
                        }
                    }
                }
                Button {
                    showTrackPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text(discCount > 1 ? "Add Music to Disc \(discCount)" : "Add Music")
                            .tint(.primary)
                    }
                    .font(.headline)
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.glassProminent)
                .sheet(isPresented: $showTrackPicker) {
                    AlbumTrackPickerView(album: [], addedTracks: $trackDrafts)
                }

                Button {
                    var split = split
                    split.appendDisc()
                    apply(split)
                } label: {
                    Label("Add a Disc", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            }
            // Новые черновики (из файлов, SoundCloud, библиотеки) приходят без
            // пластинки — кладём их на последнюю, как `Album.append`.
            .onChange(of: trackDrafts.map(\.id)) {
                placeNewDrafts()
            }
            .navigationTitle("New album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        trackDrafts.forEach(discardStagedFile)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        save()
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
                Button("OK") { dismiss() }
            } message: {
                Text(failedImports.joined(separator: "\n"))
            }
        }
    }
    
    // MARK: - Треки и пластинки

    /// Черновики одним списком, а пластинки — границами в нём, как в правке
    /// альбома. См. `DiscSplit`.
    @ViewBuilder
    private var tracksEditor: some View {
        let split = split
        let rows = split.rows
        let numbers = numbersOnDiscs(split)

        if discCount > 1 {
            DiscTitleRow(number: 1, title: titleBinding(ofDisc: 0))
        }

        ForEach(Array(rows.enumerated()), id: \.element) { index, row in
            switch row {
            case .track(let id):
                if let draftIndex = trackDrafts.firstIndex(where: { $0.id == id }) {
                    NavigationLink {
                        TrackDraftEditView(draft: $trackDrafts[draftIndex], albumArtists: artists.map(\.name))
                    } label: {
                        AlbumTrackDraftCell(draft: trackDrafts[draftIndex], position: numbers[id] ?? 0)
                    }
                }
            case .boundary(let disc):
                DiscTitleRow(number: split.number(ofBoundaryAt: index), title: titleBinding(ofDisc: disc))
            }
        }
        .onMove { source, destination in
            var split = split
            split.move(fromOffsets: source, toOffset: destination)
            apply(split)
        }
        .onDelete(perform: deleteRows)
    }

    private var split: DiscSplit<UUID> {
        let last = discCount - 1
        let discs = (0..<discCount).map { disc in
            trackDrafts.filter { min($0.disc ?? last, last) == disc }.map(\.id)
        }
        return DiscSplit(discs: discs, titles: discTitles)
    }

    /// Раскладка с экрана — в черновики: порядок, пластинки, названия.
    /// Черновики после этого лежат пластинка за пластинкой — так их и сохраняет `save`.
    private func apply(_ split: DiscSplit<UUID>) {
        let drafts = Dictionary(trackDrafts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        trackDrafts = split.discs.enumerated().flatMap { disc, ids in
            ids.compactMap { id -> TrackDraft? in
                guard var draft = drafts[id] else { return nil }
                draft.disc = disc
                return draft
            }
        }
        discTitles = split.discs.count > 1 ? split.titles : []
    }

    private func placeNewDrafts() {
        guard trackDrafts.contains(where: { $0.disc == nil }) else { return }
        apply(split)
    }

    /// Номер трека на своей пластинке, с 1.
    private func numbersOnDiscs(_ split: DiscSplit<UUID>) -> [UUID: Int] {
        var numbers: [UUID: Int] = [:]
        for disc in split.discs {
            for (index, id) in disc.enumerated() { numbers[id] = index + 1 }
        }
        return numbers
    }

    private func titleBinding(ofDisc disc: Int) -> Binding<String> {
        Binding(
            get: { discTitles.indices.contains(disc) ? discTitles[disc] : "" },
            set: { title in
                var split = split
                split.setTitle(title, ofDisc: disc)
                discTitles = split.titles
            }
        )
    }

    /// Удалённый черновик забирает с собой свой временный файл; удалённая
    /// граница сливает пластинку с предыдущей.
    private func deleteRows(at offsets: IndexSet) {
        let rows = split.rows

        var removed = Set<UUID>()
        for index in offsets {
            if case .track(let id) = rows[index] { removed.insert(id) }
        }

        for draft in trackDrafts where removed.contains(draft.id) {
            discardStagedFile(of: draft)
        }

        var split = split
        split.removeBoundaries(atOffsets: offsets)
        split.removeTracks(removed)
        apply(split)
    }

    // MARK: - Импорт

    private func handleFileLoading(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { await stageFiles(urls) }
        case .failure(let error):
            failedImports.append(error.localizedDescription)
        }
    }

    /// Теги внутри файла точнее его имени, поэтому имя файла остаётся запасным вариантом.
    private func stageFiles(_ urls: [URL]) async {
        for url in urls {
            guard let stagedURL = stage(url) else { continue }

            let metadata = await AudioMetadata.load(from: stagedURL)

            let parsedNames = metadata.artistNames.isEmpty ? url.parsedArtistNames() : metadata.artistNames
            let names = parsedNames.filter { !isAlbumArtist($0) }

            trackDrafts.append(
                TrackDraft(
                    name: metadata.title ?? url.parseMusic().name,
                    artists: names.map { ArtistDraft(name: $0, role: .featured) },
                    stagedURL: stagedURL,
                    originalURL: url
                )
            )
        }
    }

    /// Трек с SoundCloud уже лежит во временной папке — второй раз его копировать незачем,
    /// а `originalURL` пуст: в «Файлах» его никогда и не было.
    private func addDraft(from file: PickedFile, metadata: AudioMetadata) {
        let names = metadata.artistNames.filter { !isAlbumArtist($0) }

        trackDrafts.append(
            TrackDraft(
                name: metadata.title ?? file.url.parseMusic().name,
                artists: names.map { ArtistDraft(name: $0, role: .featured) },
                stagedURL: file.url
            )
        )

        // Своей обложки у альбома может ещё не быть — берём первую пришедшую.
        if artworkData == nil { artworkData = metadata.artwork }
    }

    /// Копирует выбранный файл во временную папку: доступ к URL из fileImporter короткоживущий,
    /// а сохранить альбом пользователь может сильно позже. Своя папка на файл сохраняет исходное имя.
    private func stage(_ source: URL) -> URL? {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let destination = folder.appending(path: source.lastPathComponent)

        let didAccess = source.startAccessingSecurityScopedResource()
        defer { if didAccess { source.stopAccessingSecurityScopedResource() } }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            failedImports.append(source.lastPathComponent)
            return nil
        }
    }

    /// Удаляет временную папку черновика. Черновики из уже существующих треков не трогаем:
    /// их stagedURL ведёт в документы, а не во временную папку.
    private func discardStagedFile(of draft: TrackDraft) {
        guard draft.sourceTrack == nil else { return }

        let folder = draft.stagedURL.deletingLastPathComponent()
        guard folder.deletingLastPathComponent().standardizedFileURL.path
                == URL.temporaryDirectory.standardizedFileURL.path else { return }

        try? FileManager.default.removeItem(at: folder)
    }

    private func isAlbumArtist(_ name: String) -> Bool {
        artists.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func save() {
        let album = Album(name: name, type: type, release: release, artwork: artworkData)
        album.discTitles = discCount > 1 ? discTitles : []

        modelContext.insert(album)

        // Черновики уже лежат пластинка за пластинкой (см. `apply`), поэтому
        // номер по порядку и пластинка черновика сходятся сами.
        let lastDisc = discCount - 1

        var previousAlbums = Set<Album>()

        for (index, draft) in trackDrafts.enumerated() {
            if let id = draft.sourceTrack {
                guard let track = modelContext.model(for: id) as? Track else { continue }

                if let previous = track.album {
                    previousAlbums.insert(previous)
                    previous.tracks.removeAll { $0.persistentModelID == id }
                }

                track.album = album
                track.position = index
                track.disc = min(draft.disc ?? lastDisc, lastDisc)
            } else {
                let filename: String
                do {
                    filename = try AudioFileStore.moveIntoLibrary(from: draft.stagedURL)
                } catch {
                    failedImports.append(draft.name)
                    continue
                }

                if let original = draft.originalURL {
                    AudioFileStore.removeOriginalIfNeeded(original)
                }

                let track = Track(name: draft.name, album: album, credits: [], genre: draft.genre, filename: filename)
                track.position = index
                track.disc = min(draft.disc ?? lastDisc, lastDisc)

                modelContext.insert(track)

                for (position, artistDraft) in draft.artists.enumerated() where !isAlbumArtist(artistDraft.name) {
                    let artistModel = modelContext.findOrCreateArtist(named: artistDraft.name)
                    let credit = Credit(artist: artistModel, role: artistDraft.role, position: position, track: track)

                    modelContext.insert(credit)
                }
            }
        }

        for(position, draft) in artists.enumerated() {
            let artistModel = modelContext.findOrCreateArtist(named: draft.name)
            let credit = Credit(artist: artistModel, role: draft.role, position: position, album: album)

            modelContext.insert(credit)
        }

        for previous in previousAlbums where previous.type == .single && previous.tracks.isEmpty {
            modelContext.delete(previous)
        }

        trackDrafts.forEach(discardStagedFile)

        // Есть непопавшие файлы — экран закроет кнопка в alert, чтобы список успели прочитать.
        if failedImports.isEmpty { dismiss() }
    }

}
