import SwiftUI

struct PlayerView: View {
    let audioPlayer: AudioPlayer
    /// Общее пространство имён с мини-плеером: по нему обложка перетекает
    /// из маленькой в полноэкранную вместо того, чтобы подмениться.
    let namespace: Namespace.ID

    @Binding var isPresented: Bool

    @Environment(ToastCenter.self) private var toasts

    /// Смещение при протягивании вниз — заменяет собой закрытие листа.
    @State private var dragOffset: CGFloat = 0
    
    @State private var sliderValue: TimeInterval = 0
    @State private var isScrubbing = false
    @State private var isQueuePresented = false
    @State private var isAddingToPlaylist = false
    @State private var isEditingTrack = false

    @AppStorage(AppSettings.playbackRate) private var playbackRate = 1.0
    
    @State private var artworkWidth: CGFloat = 0
    
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
        // Ставится последним, поэтому накрывает и контент, и фон шторки: на светлой
        // обложке вуаль становится светлой, а `.primary` / `.secondary` — тёмными.
        .environment(\.colorScheme, isLightBackground ? .light : .dark)
        .onAppear { sliderValue = audioPlayer.currentTime }
        .task(id: audioPlayer.currentTrack?.filename) {
            // Фоновый проход идёт по всей библиотеке подряд; тот трек, что открыт
            // прямо сейчас, ждать своей очереди не должен.
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

    /// Горизонтальные протяжки принадлежат обложке (следующий и предыдущий трек),
    /// поэтому закрытие реагирует только на явно вертикальное движение.
    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }

                if value.translation.height > 120 {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        isPresented = false
                    }
                    dragOffset = 0
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private var content: some View {
        VStack(spacing: 32) {
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
                .frame(maxWidth: .infinity)
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
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            let dx = value.translation.width
                            let dy = value.translation.height

                            // Вертикальная протяжка — не наше дело, это жест шторки.
                            guard abs(dx) > abs(dy) else { return }
                            
                            if dx < 0 {
                                audioPlayer.playNext()
                            } else {
                                audioPlayer.playPrevious()
                            }
                        }
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(audioPlayer.currentTrack?.name ?? "")
                    .font(.title2)
                    .bold()
                    .lineLimit(1)
                ArtistPillRow(artists: audioPlayer.currentTrack?.artists ?? [])
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        
            VStack(spacing: 4) {
                Slider(
                    value: $sliderValue,
                    in: 0...max(audioPlayer.duration, 0.01)
                ) { editing in
                    isScrubbing = editing
                    if !editing {
                        audioPlayer.seek(to: sliderValue)
                    }
                }
                .background {
                    if let waveformSamples {
                        WaveformView(
                            samples: waveformSamples,
                            progress: playedFraction,
                            played: audioPlayer.accent.opacity(0.35),
                            upcoming: Color.primary.opacity(0.12)
                        )
                        .frame(height: 44)
                        // Иначе волна перехватывала бы касания у слайдера.
                        .allowsHitTesting(false)
                    }
                }

                HStack {
                    Text(timeString(sliderValue))
                    Spacer()
                    Text("-" + timeString(audioPlayer.duration - sliderValue))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            controls

            Spacer()

            bottomRow
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .onChange(of: audioPlayer.currentTime) { _, newValue in
            guard !isScrubbing else { return }
            sliderValue = newValue
        }
        .onChange(of: audioPlayer.currentIndex) { _, _ in
            isScrubbing = false
            sliderValue = audioPlayer.currentTime
        }
    }
    
    /// Кнопки лежат в общем `GlassEffectContainer`: соседние стеклянные фигуры
    /// внутри него сливаются при сближении — ради этого Liquid Glass и сделан.
    /// Центральная тонируется цветом обложки, остальные остаются нейтральными.
    private var controls: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                circleButton("shuffle", size: 48, active: audioPlayer.isShuffled) {
                    audioPlayer.toggleShuffle()
                }

                circleButton("backward.fill", size: 56) {
                    audioPlayer.playPrevious()
                }

                Button {
                    audioPlayer.togglePlayPause()
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.primary)
                        .frame(width: 76, height: 76)
                }
                .glassEffect(.regular.tint(audioPlayer.accent.opacity(0.35)).interactive(), in: .circle)
                .buttonStyle(PressableButtonStyle())

                circleButton("forward.fill", size: 56) {
                    audioPlayer.playNext()
                }

                circleButton(audioPlayer.repeatMode.systemImage, size: 48, active: audioPlayer.repeatMode.isActive) {
                    audioPlayer.cycleRepeatMode()
                }
            }
        }
    }

    /// Включённый режим подсвечивается самим стеклом, а не только цветом значка —
    /// так состояние видно, пока смотришь на кнопку, а не приглядываешься к оттенку.
    private func circleButton(
        _ systemImage: String,
        size: CGFloat,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(size > 50 ? .title3 : .subheadline)
                .foregroundStyle(active ? audioPlayer.accent : Color.primary)
                .frame(width: size, height: size)
        }
        .glassEffect(
            active ? .regular.tint(audioPlayer.accent.opacity(0.25)).interactive() : .regular.interactive(),
            in: .circle
        )
        .buttonStyle(PressableButtonStyle())
    }

    private var bottomRow: some View {
        HStack(spacing: 20) {
            Button {
                audioPlayer.currentTrack?.isFavourite.toggle()
            } label: {
                Image(systemName: (audioPlayer.currentTrack?.isFavourite ?? false) ? "star.fill" : "star")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle((audioPlayer.currentTrack?.isFavourite ?? false) ? audioPlayer.accent : Color.secondary)
            .buttonStyle(PressableButtonStyle())

            Spacer()

            RoutePickerButton(
                tint: UIColor(Color.secondary),
                activeTint: UIColor(audioPlayer.accent)
            )
            .frame(width: 44, height: 44)

            Button {
                isQueuePresented = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.secondary)
            .buttonStyle(PressableButtonStyle())

            trackMenu
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

                Divider()

                speedMenu
                sleepMenu
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(.secondary)
    }

    /// Скорость лежит и в настройках, но менять её на слух удобнее там же, где слушаешь.
    private var speedMenu: some View {
        Menu {
            ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                Button {
                    playbackRate = rate
                    audioPlayer.applyPlaybackRate()
                    toasts.show(String(format: "Speed %.2f×", rate), systemImage: "speedometer")
                } label: {
                    Label(
                        String(format: "%.2f×", rate),
                        systemImage: abs(playbackRate - rate) < 0.01 ? "checkmark" : "speedometer"
                    )
                }
            }
        } label: {
            Label("Speed", systemImage: "speedometer")
        }
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

    private var waveformSamples: [UInt8]? {
        guard let data = audioPlayer.currentTrack?.waveform, !data.isEmpty else { return nil }
        return Array(data)
    }

    /// Доля сыгранного. Считается от ползунка, а не от плеера, чтобы волна
    /// закрашивалась прямо под пальцем во время перемотки.
    private var playedFraction: Double {
        guard audioPlayer.duration > 0 else { return 0 }
        return min(max(sliderValue / audioPlayer.duration, 0), 1)
    }

    /// Фон под текстом светлый — значит, сам текст должен быть тёмным.
    /// Решает не яркость обложки и не акцент, а те самые цвета, которыми залит
    /// экран: их светлота посчитана вместе с палитрой.
    private var isLightBackground: Bool { audioPlayer.palette.isLight }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(max(0, time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
