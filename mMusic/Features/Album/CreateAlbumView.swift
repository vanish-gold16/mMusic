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
                        
                    } label: {
                        VStack {
                            Text("Soundloud")
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
                if !trackDrafts.isEmpty {
                    Section {
                        ForEach(Array(trackDrafts.enumerated()), id: \.element.id) { index, draft in
                            NavigationLink {
                                TrackDraftEditView(draft: $trackDrafts[index], albumArtists: artists.map(\.name))
                            } label: {
                                AlbumTrackDraftCell(draft: draft, position: index + 1)
                            }
                        }
                        .onMove { from, to in
                            trackDrafts.move(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                discardStagedFile(of: trackDrafts[index])
                            }
                            trackDrafts.remove(atOffsets: offsets)
                        }
                    } header: {
                        HStack {
                            Text("tracks")
                            Spacer()
                            EditButton()
                        }
                    }
                }
                Button {
                    showTrackPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add Music")
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
        }
    }
    
    private func handleFileLoading(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard let stagedURL = stage(url) else { continue }

                let names = url.parsedArtistNames().filter { !isAlbumArtist($0) }

                trackDrafts.append(
                    TrackDraft(
                        name: url.parseMusic().name,
                        artists: names.map { ArtistDraft(name: $0, role: .featured) },
                        stagedURL: stagedURL
                    )
                )
            }
        case .failure(let error):
            print(error)
        }
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
            print("Staging error: \(error)")
            return nil
        }
    }

    /// Переносит подготовленный файл в документы и возвращает имя, под которым он там лежит.
    private func importStagedFile(_ stagedURL: URL) -> String? {
        let fileManager = FileManager.default
        var destination = URL.documentsDirectory.appending(path: stagedURL.lastPathComponent)

        if fileManager.fileExists(atPath: destination.path) {
            let unique = stagedURL.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString
            destination = URL.documentsDirectory
                .appending(path: unique)
                .appendingPathExtension(stagedURL.pathExtension)
        }

        do {
            try fileManager.moveItem(at: stagedURL, to: destination)
            return destination.lastPathComponent
        } catch {
            print("Import error: \(error)")
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

        modelContext.insert(album)

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
            } else {
                guard let filename = importStagedFile(draft.stagedURL) else { continue }

                let track = Track(name: draft.name, album: album, credits: [], genre: draft.genre, filename: filename)
                track.position = index

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

        dismiss()
    }

}
