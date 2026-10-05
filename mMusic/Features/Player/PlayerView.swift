import SwiftUI

/// Плеер — дека, через которую проходит музыка.
///
/// Сверху обложка, под ней паспорт трека — где он лежит на своей пластинке —
/// и имя крупным сжатым шрифтом, как на остальных экранах. Главное ниже: лента,
/// по которой трек идёт формой своей волны мимо неподвижной головки (см.
/// `PlayheadTape`), — видно не только сколько сыграно, но и что прозвучит
/// в ближайшие секунды. Под лентой — клавиши деки: включённое «залипает»
/// и зажигает лампу. В самом низу — панель с подписями вместо значков.
///
/// Тонкой полоски прогресса и ряда одинаковых круглых кнопок, по которым узнаются
/// чужие плееры, здесь нет: время — это сама музыка на ленте, кнопки — клавиши.
struct PlayerView: View {
    let audioPlayer: AudioPlayer
    /// Общее пространство имён с мини-плеером: по нему обложка перетекает
    /// из маленькой в полноэкранную вместо того, чтобы подмениться.
    let namespace: Namespace.ID

    @Binding var isPresented: Bool

    @Environment(ToastCenter.self) private var toasts

    /// Смещение при протягивании вниз — заменяет собой закрытие листа.
    @State private var dragOffset: CGFloat = 0

    @State private var isQueuePresented = false
    @State private var isAddingToPlaylist = false
    @State private var isEditingTrack = false
    /// Обложка уступила место тексту трека.
    @State private var showsLyrics = false
    @State private var isEditingLyrics = false
    @State private var isRemixPresented = false

    @State private var artworkWidth: CGFloat = 0

    private var accent: Color { audioPlayer.accent }

    var body: some View {
        // Стек нужен ради перехода на артиста.
        NavigationStack {
            VStack(spacing: 0) {
                grabber
                content
            }
            // Фон лежит внутри стека, а не надет на него снаружи: NavigationStack
            // рисует собственную непрозрачную подложку и перекрывает всё, что под ним.
            // Рамка нужна, чтобы содержимое заняло весь экран и фону было куда лечь.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { PlayerBackground(audioPlayer: audioPlayer).ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
        }
        // Экраны, открытые отсюда вглубь, продолжают фон плеера, а не встают
        // чёрным прямоугольником. Флаг доезжает и до них: environment проходит
        // сквозь границу NavigationStack.
        .environment(\.isInsidePlayer, true)
        .offset(y: dragOffset)
        // Лист заменён оверлеем: matchedGeometryEffect не работает через границу
        // листа — там своя иерархия, и обложке не с чем сопоставляться.
        .gesture(dismissGesture)
        .sheet(isPresented: $isQueuePresented) {
            QueueView(audioPlayer: audioPlayer)
        }
        .sheet(isPresented: $isAddingToPlaylist) {
            if let track = audioPlayer.currentTrack {
                AddToPlaylistView(tracks: [track])
            }
        }
        .sheet(isPresented: $isEditingTrack) {
            if let track = audioPlayer.currentTrack {
                EditTrackView(track: track)
            }
        }
        .sheet(isPresented: $isRemixPresented) {
            RemixView(audioPlayer: audioPlayer)
        }
        .sheet(isPresented: $isEditingLyrics) {
            if let track = audioPlayer.currentTrack {
                LyricsEditorView(track: track)
            }
        }
        // Ставится последним, поэтому накрывает и контент, и фон шторки: на светлой
        // обложке вуаль становится светлой, а `.primary` / `.secondary` — тёмными.
        .environment(\.colorScheme, isLightBackground ? .light : .dark)
        .task(id: audioPlayer.currentTrack?.filename) {
            // Фоновый проход идёт по всей библиотеке подряд; тот трек, что открыт
            // прямо сейчас, ждать своей очереди не должен — по его волне лента
            // рисуется, пока считается подробная.
            if let track = audioPlayer.currentTrack {
                await TrackWaveformLoader.fill(track)
            }
        }
    }

    /// Своя «ручка» вместо presentationDragIndicator — его даёт только лист.
    private var grabber: some View {
        Capsule()
            .fill(.secondary)
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    /// Горизонтальные протяжки принадлежат обложке (следующий и предыдущий трек)
    /// и ленте (перемотка), поэтому закрытие реагирует только на явно вертикальное
    /// движение.
    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                dismissDragChanged(value.translation)
            }
            .onEnded { value in
                dismissDragEnded(value.translation)
            }
    }

    /// Закрытие вынесено из жеста, потому что зовут его и обложка с лентой. У них
    /// свои протяжки, а вложенный жест забирает касание целиком — и с двух самых
    /// больших мест экрана плеер не закрывался. Теперь они передают вертикальное
    /// движение сюда.
    private func dismissDragChanged(_ translation: CGSize) {
        guard abs(translation.height) > abs(translation.width) else { return }
        dragOffset = max(0, translation.height)
    }

    private func dismissDragEnded(_ translation: CGSize) {
        if abs(translation.height) > abs(translation.width), translation.height > 120 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                isPresented = false
            }
            dragOffset = 0
        } else if dragOffset != 0 {
            // Палец мог уйти вбок посреди протяжки — плеер всё равно возвращается
            // на место, а не остаётся висеть съехавшим.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                dragOffset = 0
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // AnyLayout меняет расстановку, не подменяя сами вьюхи: обложка с
            // названием не исчезают и не появляются заново, а переезжают из
            // столбца в строку. Поэтому переход анимируется, а обложка не теряет
            // связь с мини-плеером.
            let header = showsLyrics
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 14))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))

            header {
                artwork
                titleBlock
            }
            .padding(.horizontal, 24)

            if showsLyrics {
                LyricsPanel(
                    text: audioPlayer.currentTrack?.lyrics ?? "",
                    accent: accent
                ) {
                    isEditingLyrics = true
                }
                .padding(.horizontal, 24)
                // Текст проступает, а не выпрыгивает вместе с перестроением макета.
                .transition(.opacity)
            } else {
                // Свободное место — между шапкой и декой: дека прижата к низу,
                // под большой палец, а шапка — к верху.
                Spacer(minLength: 12)
            }

            // Лента — от края до края экрана: она тянется дальше, чем видно.
            PlayheadTape(audioPlayer: audioPlayer) { translation, isFinished in
                if isFinished {
                    dismissDragEnded(translation)
                } else {
                    dismissDragChanged(translation)
                }
            }
            .padding(.top, showsLyrics ? 8 : 0)

            DeckKeys(audioPlayer: audioPlayer)
                .padding(.horizontal, 24)
                .padding(.top, 10)

            panel
                .padding(.horizontal, 24)
                .padding(.top, 4)
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    /// Обложка. Под текстом ужимается до уголка — панели нужна вся высота,
    /// а что играет, видно и по маленькой.
    private var artwork: some View {
        // Concentric — скругление, повторяющее радиус корпуса: обложка перестаёт
        // выглядеть наклеенной поверх экрана.
        ConcentricRectangle(corners: .concentric(minimum: .fixed(16)), isUniform: true)
            .fill(.quaternary)
            .overlay {
                if let data = audioPlayer.currentTrack?.displayArtwork,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(16)), isUniform: true))
            .matchedGeometryEffect(id: PlayerTransition.artwork, in: namespace, isSource: isPresented)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: showsLyrics ? 64 : .infinity)
            // Обложка лежит на фоне, а не нарисована на нём.
            .shadow(color: .black.opacity(showsLyrics ? 0 : 0.28), radius: 24, y: 12)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                artworkWidth = newWidth
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { location in
                if location.x < artworkWidth / 2 {
                    audioPlayer.playPrevious()
                } else {
                    audioPlayer.playNext()
                }
            }
            .onTapGesture {
                audioPlayer.togglePlayPause()
            }
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        // Вниз закрывается сам плеер — обложка передаёт ему движение.
                        if value.translation.height > 0 {
                            dismissDragChanged(value.translation)
                        }
                    }
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height

                        // Протяжка вверх по обложке поднимает текст — то же
                        // движение, что «поднять шторку».
                        guard abs(dx) > abs(dy) else {
                            if dy < 0 {
                                setLyrics(true)
                            } else {
                                dismissDragEnded(value.translation)
                            }
                            return
                        }

                        dismissDragEnded(value.translation)

                        if dx < 0 {
                            audioPlayer.playNext()
                        } else {
                            audioPlayer.playPrevious()
                        }
                    }
            )
    }

    /// Паспорт, имя и авторы. Под текстом остаются только имя и авторы:
    /// паспорт — подробность, а место отдано тексту.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: showsLyrics ? 4 : 6) {
            if !showsLyrics, let passport {
                Text(passport)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: 8) {
                Text(audioPlayer.currentTrack?.name ?? "")
                    .font(.system(size: showsLyrics ? 22 : 40, weight: .heavy).width(.compressed))
                    .lineLimit(showsLyrics ? 1 : 2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                favouriteButton
            }

            ArtistPillRow(artists: audioPlayer.currentTrack?.artists ?? [])
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// «A3  ·  NEVERMIND  ·  1991» — где трек лежит на своей пластинке, как на
    /// обороте конверта. У сингла имя альбома совпадает с именем трека, поэтому
    /// вместо него — формат: «SINGLE  ·  2024».
    private var passport: String? {
        guard let track = audioPlayer.currentTrack, let album = track.album else { return nil }

        var parts: [String] = []

        if let number = album.recordNumber(of: track) {
            parts.append(number)
        }

        if album.name.caseInsensitiveCompare(track.name) == .orderedSame {
            parts.append(album.type == .single ? "single" : album.type.rawValue)
        } else {
            parts.append(album.name)
        }

        if let release = album.release {
            parts.append(String(Calendar.current.component(.year, from: release)))
        }

        return parts.joined(separator: "  ·  ").uppercased()
    }

    private var favouriteButton: some View {
        let isFavourite = audioPlayer.currentTrack?.isFavourite ?? false

        return Button {
            audioPlayer.currentTrack?.isFavourite.toggle()
        } label: {
            Image(systemName: isFavourite ? "star.fill" : "star")
                .font(.title3)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(isFavourite ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")
    }

    /// Панель под клавишами. Подписи вместо значков: «TEXT» и «REMIX» понятны
    /// без угадывания, а у очереди рядом сразу видно, сколько в ней впереди.
    private var panel: some View {
        HStack(spacing: 18) {
            // Кнопка есть и у трека без текста: открытая пустая панель сама
            // предложит его добавить — иначе про возможность никто не узнает.
            PanelSwitch(title: "Text", isOn: showsLyrics, accent: accent) {
                setLyrics(!showsLyrics)
            }

            // Лампа горит, пока трек звучит не так, как записан: иначе про
            // выкрученные вчера ручки можно забыть и списать странный звук
            // на саму запись.
            PanelSwitch(title: "Remix", isOn: audioPlayer.hasRemix, accent: accent) {
                isRemixPresented = true
            }

            PanelSwitch(title: queueTitle, accent: accent) {
                isQueuePresented = true
            }

            Spacer(minLength: 0)

            RoutePickerButton(
                tint: UIColor(Color.secondary),
                activeTint: UIColor(accent)
            )
            .frame(width: 36, height: 44)

            trackMenu
        }
    }

    /// «QUEUE 12» — сколько ещё впереди. Пустая очередь — просто «QUEUE».
    private var queueTitle: String {
        let upcoming = max(audioPlayer.queue.count - audioPlayer.currentIndex - 1, 0)
        return upcoming > 0 ? "Queue \(upcoming)" : "Queue"
    }

    /// Панель едет пружиной: макет перестраивается целиком, и без анимации
    /// обложка просто скакнула бы в угол.
    private func setLyrics(_ shown: Bool) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showsLyrics = shown
        }
    }

    /// Параметры играющего трека — то же, что в меню строки списка,
    /// но под рукой, пока слушаешь.
    private var trackMenu: some View {
        Menu {
            if let track = audioPlayer.currentTrack {
                Button {
                    track.isFavourite.toggle()
                } label: {
                    Label(
                        track.isFavourite ? "Remove from favourites" : "Add to favourites",
                        systemImage: track.isFavourite ? "star.slash" : "star"
                    )
                }

                Button {
                    isAddingToPlaylist = true
                } label: {
                    Label("Add to a Playlist", systemImage: "text.badge.plus")
                }

                ShareLink(item: AudioFileStore.url(for: track.filename)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Divider()

                Button {
                    isEditingTrack = true
                } label: {
                    Label("Edit track", systemImage: "pencil")
                }

                Button {
                    isEditingLyrics = true
                } label: {
                    Label(track.hasLyrics ? "Edit text" : "Add text", systemImage: "quote.bubble")
                }

                Divider()

                Button {
                    isRemixPresented = true
                } label: {
                    Label("Remix", systemImage: "dial.medium")
                }

                sleepMenu
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                // Пока идёт таймер сна, на меню горит лампа: сам таймер живёт
                // внутри, а знать, что он идёт, полезно и не открывая.
                .overlay(alignment: .topTrailing) {
                    if audioPlayer.hasSleepTimer {
                        DeckLamp(isOn: true, accent: accent)
                            .rotationEffect(.degrees(90))
                            .padding(.top, 10)
                            .padding(.trailing, 4)
                    }
                }
        }
        .foregroundStyle(.secondary)
    }

    private var sleepMenu: some View {
        Menu {
            if audioPlayer.hasSleepTimer {
                Button(role: .destructive) {
                    audioPlayer.cancelSleepTimer()
                    toasts.removed("Sleep timer off")
                } label: {
                    Label("Turn off", systemImage: "xmark")
                }

                Divider()
            }

            Button {
                audioPlayer.stopAfterCurrentTrack()
                toasts.show("Stops after this track", systemImage: "moon.zzz")
            } label: {
                Label("End of track", systemImage: "music.note")
            }

            ForEach([15, 30, 45, 60], id: \.self) { minutes in
                Button {
                    audioPlayer.startSleepTimer(minutes: minutes)
                    toasts.show("Sleep in \(minutes) minutes", systemImage: "moon.zzz")
                } label: {
                    Label("\(minutes) minutes", systemImage: "clock")
                }
            }
        } label: {
            Label(sleepLabel, systemImage: "moon.zzz")
        }
    }

    /// Пока таймер идёт, в меню видно, сколько осталось: «on» само по себе
    /// не отвечает на вопрос «а когда?».
    private var sleepLabel: String {
        guard let endsAt = audioPlayer.sleepEndsAt else {
            return audioPlayer.stopsAfterCurrentTrack ? "Sleep timer • end of track" : "Sleep timer"
        }

        // Округление вверх: «0 min» на последних секундах читается как «уже всё».
        let minutes = max(Int(endsAt.timeIntervalSinceNow / 60) + 1, 1)
        return "Sleep timer • \(minutes) min"
    }

    /// Фон под текстом светлый — значит, сам текст должен быть тёмным.
    /// Решает не яркость обложки и не акцент, а те самые цвета, которыми залит
    /// экран: их светлота посчитана вместе с палитрой.
    private var isLightBackground: Bool { audioPlayer.palette.isLight }
}
