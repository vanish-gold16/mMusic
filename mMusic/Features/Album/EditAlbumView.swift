import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Правка альбома — та же страница будущей пластинки, что и сборка нового
/// (`CreateAlbumView`), только пластинка уже настоящая: в конверте её обложка,
/// на диске её треки кольцами, и всё, что меняешь, сразу пишется в альбом.
/// Поэтому внизу нет кнопки «сохранить» — «DONE» просто закрывает лист.
struct EditAlbumView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayer.self) private var audioPlayer

    @State private var showTrackPicker = false
    @State private var isImporting = false
    @State private var showSoundCloud = false
    @State private var addedTracks: [TrackDraft] = []
    /// Файлы, которые не удалось положить в библиотеку. Пустой список — всё прошло.
    @State private var failedImports: [String] = []
    /// Артисты альбома, пока лист открыт. В базе они лежат кредитами, а редактор
    /// работает с плоским списком — переливаем туда и обратно на открытии и закрытии.
    @State private var artistDrafts: [ArtistDraft] = []

    /// Обложка в превью, уменьшенная в фоне, и цвета, которыми светится форма.
    @State private var cover: UIImage?
    @State private var palette: CoverPalette?

    @Bindable var album: Album

    private var accent: Color {
        palette?.accent ?? audioPlayer.accent
    }

    var body: some View {
        NavigationStack {
            List {
                header
                    .bareRow()

                RecordFormSection("Artists", detail: "\(artistDrafts.count)") {
                    VStack(alignment: .leading, spacing: 10) {
                        ArtistsEditor(artists: $artistDrafts)
                        RecordHint("Tap a name to mark a guest")
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 16)
                .bareRow()

                RecordFormSection("Released") {
                    ReleaseDateField(date: $album.release)
                        .padding(.horizontal)
                }
                .padding(.top, 16)
                .bareRow()

                // Раздел показывается и у пустого альбома: раньше кнопка «Add Music»
                // пряталась вместе со списком, и положить в него первый трек
                // из библиотеки было нечем.
                RecordFormSection("Tracks", detail: album.discCount > 1 ? "\(album.discCount) discs" : "") {
                    if !album.tracks.isEmpty || album.discCount > 1 {
                        EditButton()
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.borderless)
                    }
                } content: {
                    // Песни сингла, живущие в альбоме, здесь только названы: их номер
                    // и место — в их альбоме, и правят их там.
                    ForEach(album.linkedTracks) { track in
                        RecordHint("\(track.name) lives on \"\(track.album?.name ?? "")\" — edit it there")
                            .padding(.horizontal)
                    }

                    if album.tracklist.isEmpty {
                        RecordHint("The record is empty — add tracks below")
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .bareRow()

                tracksEditor

                if album.discCount > 1 {
                    RecordHint("Drag a disc row to move where it starts. Deleting it merges the disc into the previous one.")
                        .padding(.horizontal)
                        .bareRow()
                }

                MusicSourceSlots(
                    hint: album.discCount > 1 ? "Add music to disc \(album.discCount)" : nil,
                    onLibrary: {
                        addedTracks = []
                        showTrackPicker = true
                    },
                    onFiles: { isImporting = true },
                    onSoundCloud: { showSoundCloud = true }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .bareRow()

                Button {
                    var split = split
                    split.appendDisc()
                    apply(split)
                } label: {
                    Label("Add a disc", systemImage: "record.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .padding(.horizontal)
                .padding(.bottom, 24)
                .bareRow()
            }
            .listStyle(.plain)
            .listRowSpacing(8)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .containerBackground(for: .navigation) {
                CoverAura(palette: palette, breathes: false)
            }
            // Всё в цвет обложки. Строго до `.toolbar` и листов: выбор музыки
            // остаётся в цвете приложения.
            .tint(accent)
            .task(id: album.artwork?.count) {
                let (image, colors) = await UIImage.coverAndPalette(from: album.artwork)
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.3)) {
                    cover = image
                    palette = colors
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadArtists)
            // Не по кнопке «DONE»: лист закрывают и свайпом вниз, а остальные поля
            // альбома пишутся в базу сразу — артисты не должны быть исключением.
            .onDisappear(perform: syncArtists)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetActionButton(.done) {
                        dismiss()
                    }
                }
            }
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
            .sheet(isPresented: $showTrackPicker, onDismiss: addPickedTracks) {
                AlbumTrackPickerView(album: [album], type: album.type, addedTracks: $addedTracks)
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

    // MARK: - Шапка

    /// Конверт с диском, имя, паспорт и формат — как в сборке нового альбома.
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            CoverEditMenu(artworkData: $album.artwork) {
                AlbumSleeve(
                    cover: cover,
                    type: album.type,
                    discs: album.tracklistDiscs.map { $0.map(\.duration) },
                    outDisc: album.discCount - 1,
                    playing: nil,
                    isPlaying: false,
                    accent: accent
                )
                .frame(width: 250)
            }

            VStack(alignment: .leading, spacing: 6) {
                RecordTitleField(placeholder: "Album name", text: $album.name)
                RecordPassport(parts: passport)
            }

            AlbumTypePicker(type: $album.type, accent: accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// «2×LP  ·  12 TRACKS  ·  43 MIN  ·  2024».
    private var passport: [String] {
        let tracks = album.tracklist
        var parts = [album.formatLabel]

        switch tracks.count {
        case 0: parts.append("no tracks yet")
        case 1: parts.append("1 track")
        default: parts.append("\(tracks.count) tracks")
        }

        let minutes = RecordSides.minutes(of: tracks)
        if minutes > 0 {
            parts.append(minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min")
        }

        if let release = album.release {
            parts.append(String(Calendar.current.component(.year, from: release)))
        }

        return parts
    }

    // MARK: - Треки и пластинки

    /// Треки одним списком, а пластинки — границами в нём: перетаскивая границу
    /// или трек через неё, человек решает, что на какой пластинке. Отдельного
    /// экрана для пластинок нет — см. `DiscSplit`.
    ///
    /// Строки — как на странице альбома: номер на пластинке вместо обложки
    /// (обложка у всех одна) и только приглашённые под именем.
    @ViewBuilder
    private var tracksEditor: some View {
        let split = split
        let rows = split.rows
        let tracks = tracksByID
        let numbers = numbersOnDiscs(split)

        // Название первой пластинки — над списком: её граница не двигается,
        // она и есть начало альбома.
        if album.discCount > 1 {
            DiscTitleRow(number: 1, title: titleBinding(ofDisc: 0))
                .padding(.horizontal)
                .bareRow()
        }

        ForEach(Array(rows.enumerated()), id: \.element) { index, row in
            switch row {
            case .track(let id):
                if let track = tracks[id] {
                    TrackCell(
                        track: track,
                        showDuration: true,
                        number: "\(numbers[id] ?? 0)",
                        showsOnlyGuests: true
                    )
                    .bareRow()
                }
            case .boundary(let disc):
                DiscTitleRow(number: split.number(ofBoundaryAt: index), title: titleBinding(ofDisc: disc))
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .bareRow()
            }
        }
        .onMove { source, destination in
            var split = split
            split.move(fromOffsets: source, toOffset: destination)
            apply(split)
        }
        .onDelete(perform: deleteRows)
    }

    /// Номер трека на своей пластинке, с 1.
    private func numbersOnDiscs(_ split: DiscSplit<PersistentIdentifier>) -> [PersistentIdentifier: Int] {
        var numbers: [PersistentIdentifier: Int] = [:]
        for disc in split.discs {
            for (index, id) in disc.enumerated() { numbers[id] = index + 1 }
        }
        return numbers
    }

    private var split: DiscSplit<PersistentIdentifier> {
        DiscSplit(discs: album.discs.map { $0.map(\.persistentModelID) }, titles: album.discTitles)
    }

    private var tracksByID: [PersistentIdentifier: Track] {
        Dictionary(album.tracks.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Раскладка с экрана — в альбом: номера и пластинки треков, названия пластинок.
    private func apply(_ split: DiscSplit<PersistentIdentifier>) {
        let tracks = tracksByID
        album.arrange(split.discs.map { $0.compactMap { tracks[$0] } }, titles: split.titles)
    }

    private func titleBinding(ofDisc disc: Int) -> Binding<String> {
        Binding(
            get: { album.title(ofDisc: disc) },
            set: { title in
                var split = split
                split.setTitle(title, ofDisc: disc)
                album.discTitles = split.titles
            }
        )
    }

    /// Удаление строк. Трек убирается из альбома, но не из библиотеки: файл
    /// и запись остаются, пропадает только принадлежность альбому. Граница
    /// убирает пластинку, а её треки переходят на предыдущую.
    ///
    /// Раньше трек убирался снятием галочки в листе добавления — и стоило там
    /// чему-нибудь не совпасть, как из альбома исчезало всё разом.
    private func deleteRows(at offsets: IndexSet) {
        let rows = split.rows
        let tracks = tracksByID

        var removed = Set<PersistentIdentifier>()
        for index in offsets {
            if case .track(let id) = rows[index] { removed.insert(id) }
        }

        var split = split
        split.removeBoundaries(atOffsets: offsets)
        split.removeTracks(removed)

        // Песня, вышедшая ещё и синглом, возвращается на сингл, а не остаётся без альбома.
        for id in removed {
            guard let track = tracks[id], !track.returnToSingle() else { continue }
            track.album = nil
            track.disc = 0
        }

        apply(split)
    }

    // MARK: - Импорт

    /// Импортирует выбранные аудиофайлы в альбом, добавляя треки в конец —
    /// на последнюю пластинку.
    private func handleFileLoading(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var imported: [Track] = []

            for url in urls {
                let filename: String
                do {
                    filename = try AudioFileStore.importFile(from: url)
                } catch {
                    failedImports.append(url.lastPathComponent)
                    continue
                }

                let track = Track(name: url.parseMusic().name, credits: [], genre: .pop, filename: filename)

                modelContext.insert(track)
                // Альбом ставит `append`: он же выдаёт номер и пластинку.
                album.append([track])
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
            credits: [],
            genre: .pop,
            filename: filename,
            artwork: metadata.artwork
        )

        modelContext.insert(track)
        // Альбом ставит `append`: он же выдаёт номер. Сам по себе трек номера не знает.
        album.append([track])

        let names = metadata.artistNames.filter { name in
            !albumArtistNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        }

        for (position, name) in names.enumerated() {
            let artistModel = modelContext.findOrCreateArtist(named: name)
            modelContext.insert(Credit(artist: artistModel, role: .featured, position: position, track: track))
        }
    }

    /// Артисты альбома на экране. Пока лист открыт, правда — в черновиках:
    /// в базу они уезжают на закрытии, а импортировать файл могут раньше, и
    /// новый альбомный артист не должен попасть ещё и в credits трека.
    private var albumArtistNames: [String] { artistDrafts.map(\.name) }

    private func loadArtists() {
        artistDrafts = album.credits
            .sorted { $0.position < $1.position }
            .map { ArtistDraft(name: $0.artist.name, role: $0.role) }
    }

    /// Кредиты альбома пересобираются из черновиков: имя, роль и порядок задаёт
    /// список на экране, а связь «кто есть кто» ищется по имени, чтобы одного
    /// артиста не завести дважды.
    ///
    /// Пересборка целиком — потому что править нечего: у кредита нет ничего, кроме
    /// артиста, роли и позиции. Но если ничего не изменилось, не трогаем и их:
    /// лист закрывают и просто посмотрев, а каждая пересборка — запись в базу.
    private func syncArtists() {
        let current = album.credits
            .sorted { $0.position < $1.position }
            .map { ($0.artist.name, $0.role) }
        let edited = artistDrafts.map { ($0.name, $0.role) }

        guard current.count != edited.count
                || zip(current, edited).contains(where: { $0 != $1 })
        else { return }

        for credit in Array(album.credits) {
            modelContext.delete(credit)
        }

        for (position, draft) in artistDrafts.enumerated() {
            let artist = modelContext.findOrCreateArtist(named: draft.name)
            let credit = Credit(artist: artist, role: draft.role, position: position, album: album)

            modelContext.insert(credit)
        }
    }

    /// Добавляет выбранное в конец альбома. Сам перенос — в `Album.append`,
    /// здесь только превращение черновиков обратно в треки.
    private func addPickedTracks() {
        defer { addedTracks = [] }

        let picked = addedTracks.compactMap { draft -> Track? in
            guard let id = draft.sourceTrack else { return nil }
            return modelContext.model(for: id) as? Track
        }

        album.append(picked, albumArtists: albumArtistNames)
    }
}
