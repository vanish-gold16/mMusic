import SwiftData
import SwiftUI

/// Главная — комната с проигрывателем, а не витрина рекомендаций.
///
/// Сверху день и то, как звучала неделя. Дальше — проигрыватель с тем, что
/// играет или на чём остановились, кассета-микстейп, которую приложение
/// записало из твоей библиотеки, стопка недавно игравших пластинок и одна
/// давно забытая, вытащенная из ящика наугад. Ни одной ленты квадратных
/// карточек: всё нарисовано тем же языком, что и библиотека, — конверты,
/// диски, ленты.
struct HomeView: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toasts
    /// Приложение могли не закрывать сутками — тогда о новом дне узнаём только
    /// по возвращению из фона.
    @Environment(\.scenePhase) private var scenePhase

    /// Только те, что уже играли: у остальных `lastPlayedAt` пуст и в стопке им не место.
    @Query(
        filter: #Predicate<Track> { $0.lastPlayedAt != nil },
        sort: \Track.lastPlayedAt,
        order: .reverse
    ) private var playedTracks: [Track]

    @Query private var allTracks: [Track]
    @Query private var albums: [Album]

    /// Номер кассеты на наклейке: сколько миксов приложение уже записало.
    @AppStorage("mixtapeNumber") private var mixtapeNumber = 0

    @State private var showSettings = false
    @State private var showImport = false
    /// Микс живёт в состоянии, а не пересчитывается в `body`: иначе он перетасовывался
    /// бы на каждую перерисовку и кнопка «play» запускала бы не то, что показано.
    @State private var mix: [Track] = []
    /// Сколько треков было в библиотеке, когда записывали микс. `.task` перезапускается
    /// при каждом возвращении на вкладку — по этому числу видно, менялась ли библиотека
    /// и пора ли переписывать кассету.
    @State private var mixLibraryCount = -1
    @State private var mixPalette: CoverPalette?
    /// Пластинка из ящика. Выбирается один раз и меняется только по кнопке,
    /// а не при каждом заходе на вкладку.
    @State private var dig: Album?
    /// Треки, у которых сегодня годовщина. Считаются в `.task`: там поход в историю
    /// прослушиваний, и делать его на каждой перерисовке незачем.
    @State private var birthdays: [TrackBirthday] = []
    @State private var week: ListeningWeek = .empty
    @State private var now: Date = .now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                HomeMasthead(week: week, now: now, accent: audioPlayer.accent)
                    .padding(.top, 4)

                if allTracks.isEmpty {
                    emptyLibrary
                } else {
                    content
                }
            }
            .padding(.bottom, 32)
        }
        // `containerBackground`, а не `background`: у экрана в навигации своя
        // непрозрачная подложка. Комната светится цветом того, что на проигрывателе.
        .containerBackground(for: .navigation) {
            CoverAura(palette: audioPlayer.currentTrack == nil ? nil : audioPlayer.palette, breathes: true)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showImport) {
            NavigationStack {
                DownloadView()
            }
        }
        .task(id: allTracks.count) {
            // Перезапускается и при каждом возвращении на вкладку — кассета
            // переписывается, только если библиотека с тех пор изменилась:
            // иначе удалённый трек висел бы в миксе ссылкой.
            if mix.isEmpty || mixLibraryCount != allTracks.count {
                refreshMix()
            }
            if dig == nil || dig?.isDeleted == true {
                digCrate()
            }
            refreshDay()
        }
        .task(id: mix.first?.id) {
            await loadMixPalette()
        }
        // Неделя меняется, пока музыка играет: на каждом новом треке
        // прошлый уже досчитан в истории.
        .task(id: audioPlayer.currentTrack?.id) {
            week = ListeningWeek.make(in: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            // Полночь наступает и при открытом приложении: без этого вчерашний
            // именинник висел бы на экране, а шапка жила бы вчерашним днём.
            guard phase == .active else { return }
            refreshDay()
        }
    }

    // MARK: - Содержимое

    @ViewBuilder
    private var content: some View {
        if !birthdays.isEmpty {
            birthdaySection
        }

        if let track = audioPlayer.currentTrack {
            NowSpinning(track: track)
        }

        if !mix.isEmpty {
            MixtapeSection(
                mix: mix,
                number: mixtapeNumber,
                palette: mixPalette,
                onReroll: refreshMix,
                onKeep: keepMix
            )
        }

        if !pile.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                CrateDivider(title: "SPUN LATELY", detail: pile.count == 1 ? "1 RECORD" : "\(pile.count) RECORDS", size: 22)
                    .padding(.horizontal)

                RecordPile(records: pile)
            }
        }

        if let dig, !dig.isDeleted {
            VStack(alignment: .leading, spacing: 14) {
                CrateDivider(title: "FROM THE CRATE", detail: "DUSTY", size: 22)
                    .padding(.horizontal)

                CrateDig(album: dig, lastPlayedAt: lastPlayed(dig), onDigAgain: digCrate)
            }
        }
    }

    /// Пустая библиотека: комната есть, музыки нет. Пунктир — как везде,
    /// где «сюда можно положить».
    private var emptyLibrary: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashedSlot(title: "Import music", systemImage: "square.and.arrow.down", isLarge: true) {
                showImport = true
            }

            Text("The turntable is waiting. Bring in some files or a SoundCloud link.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    /// Праздник — сверху: он бывает редко и живёт один день.
    private var birthdaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(birthdays.count == 1 ? "Track birthday" : "Track birthdays")

            if birthdays.count == 1, let birthday = birthdays.first {
                BirthdayCard(birthday: birthday) { play(birthday.track) }
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(birthdays) { birthday in
                            BirthdayCard(birthday: birthday) { play(birthday.track) }
                                .frame(width: 300)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Стопка и ящик

    /// Недавно игравшие альбомы, последний сверху. Трек считается за свой альбом:
    /// в стопке лежат пластинки, а не песни. Играющая тоже здесь — она выдвинута.
    private var pile: [PiledRecord] {
        var seen = Set<PersistentIdentifier>()
        var records: [PiledRecord] = []

        for track in playedTracks where records.count < 6 {
            guard let album = track.album, let playedAt = track.lastPlayedAt,
                  seen.insert(album.persistentModelID).inserted
            else { continue }

            records.append(PiledRecord(album: album, lastPlayedAt: playedAt))
        }

        return records
    }

    private func lastPlayed(_ album: Album) -> Date? {
        album.tracks.compactMap(\.lastPlayedAt).max()
    }

    /// Достаёт из ящика альбом, который не ставили месяц или не ставили никогда.
    /// Из стопки и с проигрывателя не берёт — о них и так помнят. Если забытых
    /// нет, подойдёт любой, кроме тех же.
    private func digCrate() {
        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now

        var excluded = Set(pile.map(\.id))
        if let album = audioPlayer.currentTrack?.album { excluded.insert(album.persistentModelID) }
        if let dig { excluded.insert(dig.persistentModelID) }

        let candidates = albums.filter { !$0.tracks.isEmpty && !excluded.contains($0.persistentModelID) }
        let dusty = candidates.filter { (lastPlayed($0) ?? .distantPast) < monthAgo }

        dig = dusty.randomElement() ?? candidates.randomElement() ?? dig
    }

    // MARK: - Микс

    private func refreshMix() {
        mix = Array(allTracks.shuffled().prefix(25))
        mixLibraryCount = allTracks.count
        mixtapeNumber += 1
    }

    /// Цвета наклейки — первой обложки в миксе.
    private func loadMixPalette() async {
        guard let data = mix.lazy.compactMap(\.displayArtwork).first else {
            mixPalette = nil
            return
        }

        let palette = await Task.detached(priority: .utility) {
            UIImage.thumbnail(from: data, side: 200)?.coverPalette
        }.value

        guard !Task.isCancelled else { return }
        mixPalette = palette
    }

    /// Кассета живёт до следующей перезаписи — эта кнопка оставляет удачную
    /// подборку плейлистом. Имя — с номера на наклейке.
    private func keepMix() {
        guard !mix.isEmpty else { return }

        let playlist = Playlist(name: "Mixtape No. \(mixtapeNumber)", items: [])
        modelContext.insert(playlist)

        for (position, track) in mix.enumerated() {
            modelContext.insert(TrackPlaylistItem(track: track, playlist: playlist, position: position))
        }

        toasts.show("Kept as \(playlist.name)", systemImage: "text.badge.plus")
    }

    // MARK: - День

    private func refreshDay() {
        now = .now
        week = ListeningWeek.make(in: modelContext)
        birthdays = TrackBirthday.today(in: allTracks, listened: TrackBirthday.listened(in: modelContext))
    }

    /// Именинник играет один: ставить за ним всю библиотеку — не то, чего ждёшь
    /// от нажатия на плашку про конкретный трек.
    private func play(_ track: Track) {
        audioPlayer.play([track])
    }
}
