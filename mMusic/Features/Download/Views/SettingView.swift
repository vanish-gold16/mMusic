import AVFoundation
import SwiftUI
import SwiftData

/// Форма нового трека. Трек здесь не строчка в таблице полей, а будущая
/// пластинка: наверху конверт с выехавшим диском, и кольцо нового трека
/// горит на нём акцентом. Выбрал «новый сингл» — диск маленький, из одного
/// кольца; выбрал альбом — это его конверт, и кольцо встаёт последним
/// на его последнюю пластинку. Видно, куда трек ляжет, до того как он лёг.
///
/// Остальное — как на страницах плейлиста и альбома: имя крупным сжатым
/// шрифтом прямо в шапке, разделы под метками-разделителями, свечение
/// цветами обложки сверху.
struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer

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

    /// Обложка в превью, уменьшенная в фоне, и цвета, которыми светится форма.
    @State private var cover: UIImage?
    @State private var palette: CoverPalette?
    /// Длительность из самого файла — ей задаётся толщина кольца на диске.
    @State private var duration: TimeInterval = 0

    @FocusState private var isNameFocused: Bool

    /// Свежие слева: трек обычно докладывают в недавно добавленный альбом.
    @Query(sort: \Album.addedAt, order: .reverse) private var albums: [Album]

    let file: PickedFile
    /// Метаданные, добытые не из файла (например, из SoundCloud). Если они есть,
    /// теги самого файла не читаются: у скачанного mp3 их может не быть вовсе.
    let preset: AudioMetadata?
    /// «2 OF 5», когда файлов выбрали несколько и формы идут друг за другом.
    let step: String?
    /// Трек лёг в библиотеку — окно импорта показывает его в «Just added».
    let onSaved: ((Track) -> Void)?

    private var accent: Color {
        palette?.accent ?? audioPlayer.accent
    }

    /// Что будет видно в библиотеке: у трека в альбоме — обложка альбома,
    /// своя только если у альбома её нет (см. `Track.displayArtwork`).
    private var previewArtwork: Data? {
        destinationAlbum?.artwork ?? artworkData
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    section("Artists", detail: "\(artists.count)") {
                        VStack(alignment: .leading, spacing: 10) {
                            ArtistsEditor(artists: $artists)

                            // Роль переключается нажатием на капсулу — без подсказки
                            // до этого не догадаться.
                            Text("TAP A NAME TO MARK A GUEST")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .tracking(1.2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                    }

                    section("Album", detail: destinationAlbum?.formatLabel ?? "New single") {
                        AlbumDestinationStrip(albums: albums, selection: $destinationAlbum)
                    }

                    section("Genre") {
                        genreMenu
                            .padding(.horizontal)
                    }

                    // У существующего альбома свои обложка и дата — трек их наследует.
                    if destinationAlbum == nil {
                        section("Released") {
                            releaseRow
                                .padding(.horizontal)
                        }
                    }

                    linerNotes
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
                .animation(.snappy, value: destinationAlbum == nil)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
            .containerBackground(for: .navigation) {
                CoverAura(palette: palette, breathes: false)
            }
            // Всё в цвет обложки. Строго до `.toolbar` и листов: выбор картинки
            // остаётся в цвете приложения.
            .tint(accent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                if let step {
                    ToolbarItem(placement: .principal) {
                        Text(step)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(imageData: $artworkData)
            }
            .task {
                await loadMetadata()
            }
            .task {
                await loadDuration()
            }
            .task(id: previewArtwork?.count) {
                await loadCover()
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

    // MARK: - Шапка

    /// Конверт с диском, имя и паспорт.
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            sleeve

            VStack(alignment: .leading, spacing: 6) {
                // Имя правится прямо в шапке, тем же шрифтом, каким будет стоять
                // на странице альбома: что видишь, то и получишь.
                TextField("Track name", text: $name, axis: .vertical)
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .lineLimit(1...3)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onChange(of: name) { _, newValue in
                        // В многострочном поле Return вставляет перенос — а имени
                        // трека перенос не нужен, Return здесь значит «готово».
                        guard newValue.contains("\n") else { return }
                        name = newValue.replacingOccurrences(of: "\n", with: "")
                        isNameFocused = false
                    }

                Text(passport)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    /// Конверт будущей пластинки. У сингла его обложку меняют нажатием;
    /// у альбома обложка его собственная, и трек её не трогает.
    @ViewBuilder
    private var sleeve: some View {
        let preview = AlbumSleeve(
            cover: cover,
            type: destinationAlbum?.type ?? .single,
            discs: previewDiscs,
            outDisc: previewDiscs.count - 1,
            playing: previewPosition,
            isPlaying: false,
            accent: accent
        )
        .frame(width: 250)
        .animation(.spring(duration: 0.5, bounce: 0.2), value: destinationAlbum?.persistentModelID)

        if destinationAlbum == nil {
            Menu {
                Button {
                    showImagePicker = true
                } label: {
                    Label(artworkData == nil ? "Add cover" : "Change cover", systemImage: "photo")
                }

                if artworkData != nil {
                    Button(role: .destructive) {
                        artworkData = nil
                    } label: {
                        Label("Remove cover", systemImage: "trash")
                    }
                }
            } label: {
                preview
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: "camera.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(9)
                            .background(.thinMaterial, in: Circle())
                            .padding(10)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cover")
        } else {
            preview
        }
    }

    /// Пластинки превью: у сингла одна, из одного кольца; у альбома — его
    /// пластинки, и новый трек кольцом в конце последней, куда его и положит `append`.
    private var previewDiscs: [[TimeInterval]] {
        guard let album = destinationAlbum else { return [[duration]] }

        var discs = album.discs.map { $0.map(\.duration) }
        if discs.isEmpty { discs = [[]] }
        discs[discs.count - 1].append(duration)
        return discs
    }

    private var previewPosition: DiscPosition {
        let discs = previewDiscs
        return DiscPosition(disc: discs.count - 1, track: discs[discs.count - 1].count - 1)
    }

    /// «NEW SINGLE  ·  3:41» или «LP  ·  TRACK 8  ·  3:41».
    private var passport: String {
        var parts: [String] = []

        if let album = destinationAlbum {
            parts.append(album.formatLabel)
            parts.append("track \(album.tracks.count + 1)")
        } else {
            parts.append("new single")
        }

        if duration > 0 {
            parts.append(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
        }

        return parts.joined(separator: "  ·  ").uppercased()
    }

    // MARK: - Разделы

    private func section<Content: View>(
        _ title: String,
        detail: String = "",
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CrateDivider(title: title.uppercased(), detail: detail.uppercased(), size: 22)
                .padding(.horizontal)

            content()
        }
    }

    /// Жанр — крупным словом в стеклянной капсуле, а не строкой таблицы.
    /// Вариантов шесть десятков, поэтому выбор — системным меню, где их видно столбцом.
    private var genreMenu: some View {
        Menu {
            Picker("Genre", selection: $genre) {
                ForEach(Genre.allCases, id: \.self) { genre in
                    Text(genre.rawValue).tag(genre)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(genre.rawValue)
                    .font(.system(size: 26, weight: .heavy).width(.compressed))
                    .foregroundStyle(Color.primary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
            .glassEffect()
        }
        .buttonStyle(.plain)
    }

    /// Дата выхода сингла. Её может и не быть — тогда на её месте пустой
    /// пунктирный слот, как у всех «сюда можно что-то положить».
    @ViewBuilder
    private var releaseRow: some View {
        if hasReleaseOn {
            HStack(spacing: 8) {
                DatePicker("Release date", selection: $release, displayedComponents: .date)
                    .labelsHidden()

                Button {
                    hasReleaseOn = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove release date")
            }
        } else {
            DashedSlot(title: "Add release date", systemImage: "calendar", cornerRadius: 26) {
                hasReleaseOn = true
            }
            .frame(maxWidth: 220)
        }
    }

    /// Откуда трек — мелко внизу, как выходные данные на обороте конверта.
    private var linerNotes: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(.quaternary)
                .frame(width: 32, height: 1)
                .padding(.bottom, 6)

            Text(preset == nil ? "From files" : "From SoundCloud")
            Text(file.url.lastPathComponent)
                .lineLimit(2)
        }
        .textCase(.uppercase)
        .font(.caption2)
        .fontWeight(.semibold)
        .tracking(1.2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Label("Add to library", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.glassProminent)
        // Трек без имени в библиотеке не найти и не отличить от соседей.
        .disabled(trimmedName.isEmpty)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// Поля заполняются разбором имени файла сразу, чтобы форма не открывалась пустой.
    /// Теги из самого файла приходят следом, в `loadMetadata`.
    init(file: PickedFile, step: String? = nil, onSaved: ((Track) -> Void)? = nil) {
        self.file = file
        self.preset = file.preset
        self.step = step
        self.onSaved = onSaved
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
    
    /// Длительность — для толщины кольца в превью. В библиотеку её запишет
    /// `TrackDurationLoader`, как и всем трекам.
    private func loadDuration() async {
        let url = file.url
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let time = try? await AVURLAsset(url: url).load(.duration) else { return }

        let seconds = CMTimeGetSeconds(time)
        if seconds.isFinite, seconds > 0 {
            duration = seconds
        }
    }

    /// Обложку превью и её цвета считаем в фоне: картинка из тегов бывает
    /// в несколько мегабайт.
    private func loadCover() async {
        let data = previewArtwork

        let (image, colors) = await Task.detached(priority: .utility) {
            let image = data.flatMap { UIImage.thumbnail(from: $0, side: 600) }
            return (image, image?.coverPalette)
        }.value

        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            cover = image
            palette = colors
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

        let track = if let album = destinationAlbum {
            addToExisting(album, filename: filename)
        } else {
            createSingle(filename: filename)
        }

        onSaved?(track)
        dismiss()
    }

    /// Обычный импорт: трек и одноимённый альбом-сингл, авторство на альбоме.
    @discardableResult
    private func createSingle(filename: String) -> Track {
        let album = Album(name: trimmedName, type: .single, release: hasReleaseOn ? release : nil, artwork: artworkData)
        let track = Track(name: trimmedName, album: album, credits: [], genre: genre, filename: filename)

        modelContext.insert(album)
        modelContext.insert(track)

        for (position, draft) in artists.enumerated() {
            let artistModel = modelContext.findOrCreateArtist(named: draft.name)
            let credit = Credit(artist: artistModel, role: draft.role, position: position, album: album)

            modelContext.insert(credit)
        }

        return track
    }

    /// Трек в существующий альбом. Авторов альбома он наследует, поэтому в его
    /// собственные credits попадают только те, кого в альбоме ещё нет.
    @discardableResult
    private func addToExisting(_ album: Album, filename: String) -> Track {
        let track = Track(name: trimmedName, credits: [], genre: genre, filename: filename)
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

        return track
    }

}
