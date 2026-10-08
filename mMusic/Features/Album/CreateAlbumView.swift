import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Сборка нового альбома. Как и форма нового трека, это не таблица полей,
/// а будущая пластинка: наверху конверт, из которого выезжает диск, и каждый
/// добавленный трек ложится на него кольцом своей длины. Переключил формат —
/// диск стал меньше или больше; добавил пластинку — за конвертом появилась
/// стопка.
///
/// Музыку берут из трёх мест — библиотеки, файлов и SoundCloud — тремя
/// пунктирными слотами под списком треков: это пустые места, куда она ляжет.
/// Пустой кнопки «From YouTube» больше нет: она ничего не делала.
struct CreateAlbumView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayer.self) private var audioPlayer
    
    @State private var name = ""
    @State private var trackDrafts: [TrackDraft] = []
    @State private var artworkData: Data?
    @State private var artists: [ArtistDraft] = []
    @State private var release: Date?
    @State private var type: Album.AlbumType = .single
    
    @State private var showTrackPicker = false
    @State private var isImporting = false
    @State private var showSoundCloud = false
    /// Черновик, открытый на правку. Строка — кнопка, а не `NavigationLink`:
    /// у ссылки в списке свой шеврон, и он вылезал бы за стеклянную капсулу.
    @State private var editingDraft: UUID?
    /// Файлы, которые не удалось положить в библиотеку. Пустой список — всё прошло.
    @State private var failedImports: [String] = []
    /// Названия пластинок будущего альбома. Пусто — пластинка одна.
    @State private var discTitles: [String] = []

    /// Обложка в превью, уменьшенная в фоне, и цвета, которыми светится форма.
    @State private var cover: UIImage?
    @State private var palette: CoverPalette?

    private var discCount: Int { max(discTitles.count, 1) }

    private var accent: Color {
        palette?.accent ?? audioPlayer.accent
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        NavigationStack {
            List {
                header
                    .bareRow()

                RecordFormSection("Artists", detail: "\(artists.count)") {
                    VStack(alignment: .leading, spacing: 10) {
                        ArtistsEditor(artists: $artists)
                        RecordHint("Tap a name to mark a guest")
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 16)
                .bareRow()

                RecordFormSection("Released") {
                    ReleaseDateField(date: $release)
                        .padding(.horizontal)
                }
                .padding(.top, 16)
                .bareRow()

                RecordFormSection("Tracks", detail: tracksDetail) {
                    if !trackDrafts.isEmpty || discCount > 1 {
                        EditButton()
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.borderless)
                    }
                } content: {
                    if trackDrafts.isEmpty {
                        RecordHint("The record is empty — add the first tracks below")
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .bareRow()

                tracksEditor

                if discCount > 1 {
                    RecordHint("Drag a disc row to move where it starts. Deleting it merges the disc into the previous one.")
                        .padding(.horizontal)
                        .bareRow()
                }

                // Куда ляжет музыка, важно, только когда пластинок несколько.
                MusicSourceSlots(
                    hint: discCount > 1 ? "Add music to disc \(discCount)" : nil,
                    onLibrary: { showTrackPicker = true },
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
            .safeAreaInset(edge: .bottom) {
                createButton
            }
            .containerBackground(for: .navigation) {
                CoverAura(palette: palette, breathes: false)
            }
            // Всё в цвет обложки. Строго до `.toolbar` и листов: выбор музыки
            // остаётся в цвете приложения.
            .tint(accent)
            .navigationDestination(item: $editingDraft) { id in
                if let index = trackDrafts.firstIndex(where: { $0.id == id }) {
                    TrackDraftEditView(draft: $trackDrafts[index], albumArtists: artists.map(\.name))
                }
            }
            // Новые черновики (из файлов, SoundCloud, библиотеки) приходят без
            // пластинки — кладём их на последнюю, как `Album.append`.
            .onChange(of: trackDrafts.map(\.id)) {
                placeNewDrafts()
            }
            .task(id: artworkData?.count) {
                let (image, colors) = await UIImage.coverAndPalette(from: artworkData)
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.3)) {
                    cover = image
                    palette = colors
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetActionButton(.scrap) {
                        trackDrafts.forEach(discardStagedFile)
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
                    addDraft(from: file, metadata: metadata)
                }
            }
            .sheet(isPresented: $showTrackPicker) {
                AlbumTrackPickerView(album: [], addedTracks: $trackDrafts)
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

    // MARK: - Шапка

    /// Конверт с диском, имя, паспорт и формат.
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            CoverEditMenu(artworkData: $artworkData) {
                AlbumSleeve(
                    cover: cover,
                    type: type,
                    discs: previewDiscs,
                    outDisc: previewDiscs.count - 1,
                    playing: nil,
                    isPlaying: false,
                    accent: accent
                )
                .frame(width: 250)
            }

            VStack(alignment: .leading, spacing: 6) {
                RecordTitleField(placeholder: "Album name", text: $name)
                RecordPassport(parts: passport)
            }

            AlbumTypePicker(type: $type, accent: accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// Пластинки превью: каждый черновик — кольцо своей длины на своей пластинке.
    private var previewDiscs: [[TimeInterval]] {
        let drafts = Dictionary(trackDrafts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return split.discs.map { ids in
            ids.compactMap { drafts[$0] }.map(duration(of:))
        }
    }

    /// «2×LP  ·  12 TRACKS  ·  43 MIN  ·  2024».
    private var passport: [String] {
        var parts = [discCount > 1 ? "\(discCount)×\(type.rawValue)" : type.rawValue]

        switch trackDrafts.count {
        case 0: parts.append("no tracks yet")
        case 1: parts.append("1 track")
        default: parts.append("\(trackDrafts.count) tracks")
        }

        let minutes = Int((trackDrafts.reduce(0) { $0 + duration(of: $1) } / 60).rounded())
        if minutes > 0 {
            parts.append(minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min")
        }

        if let release {
            parts.append(String(Calendar.current.component(.year, from: release)))
        }

        return parts
    }

    private var tracksDetail: String {
        discCount > 1 ? "\(discCount) discs" : ""
    }

    /// У трека из библиотеки длительность уже лежит в нём самом, у файла — в черновике.
    private func duration(of draft: TrackDraft) -> TimeInterval {
        if let id = draft.sourceTrack, let track = modelContext.model(for: id) as? Track {
            return track.duration
        }
        return draft.duration
    }

    // MARK: - Сохранение

    private var createButton: some View {
        Button {
            save()
        } label: {
            Label("Create album", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.glassProminent)
        // Альбом без имени в библиотеке не найти и не отличить от соседей.
        .disabled(trimmedName.isEmpty)
        .padding(.horizontal)
        .padding(.bottom, 8)
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
                .padding(.horizontal)
                .bareRow()
        }

        ForEach(Array(rows.enumerated()), id: \.element) { index, row in
            switch row {
            case .track(let id):
                if let draft = trackDrafts.first(where: { $0.id == id }) {
                    Button {
                        editingDraft = id
                    } label: {
                        AlbumTrackDraftCell(draft: draft, position: numbers[id] ?? 0, duration: duration(of: draft))
                    }
                    .buttonStyle(.plain)
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
                    originalURL: url,
                    duration: await TrackDurationLoader.duration(of: stagedURL) ?? 0
                )
            )

            // Своей обложки у альбома может ещё не быть — берём первую пришедшую.
            if artworkData == nil { artworkData = metadata.artwork }
        }
    }

    /// Трек с SoundCloud уже лежит во временной папке — второй раз его копировать незачем,
    /// а `originalURL` пуст: в «Файлах» его никогда и не было.
    private func addDraft(from file: PickedFile, metadata: AudioMetadata) {
        let names = metadata.artistNames.filter { !isAlbumArtist($0) }

        let draft = TrackDraft(
            name: metadata.title ?? file.url.parseMusic().name,
            artists: names.map { ArtistDraft(name: $0, role: .featured) },
            stagedURL: file.url
        )
        trackDrafts.append(draft)

        // Длительность дочитывается следом: лист SoundCloud отдаёт файл синхронно.
        Task {
            guard let seconds = await TrackDurationLoader.duration(of: file.url),
                  let index = trackDrafts.firstIndex(where: { $0.id == draft.id }) else { return }
            trackDrafts[index].duration = seconds
        }

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
