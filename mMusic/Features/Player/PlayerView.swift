import SwiftUI

struct PlayerView: View {
    let audioPlayer: AudioPlayer
    /// Общее пространство имён с мини-плеером: по нему обложка перетекает
    /// из маленькой в полноэкранную вместо того, чтобы подмениться.
    let namespace: Namespace.ID

    @Binding var isPresented: Bool

    /// Смещение при протягивании вниз — заменяет собой закрытие листа.
    @State private var dragOffset: CGFloat = 0
    
    @State private var sliderValue: TimeInterval = 0
    @State private var isScrubbing = false
    @State private var isQueuePresented = false
    @State private var isAddingToPlaylist = false
    @State private var isEditingTrack = false

    @AppStorage(AppSettings.playbackRate) private var playbackRate = 1.0
    
    /// Сглаженная громкость для фона: тянется за `audioPlayer.level`, но лениво,
    /// иначе фон мигал бы на каждой ноте.
    @State private var glow: Double = 0
    @State private var artworkWidth: CGFloat = 0

    /// Ползучие границы громкости этого трека — подстраиваются сами,
    /// чтобы фон одинаково хорошо дышал и на тихой записи, и на громкой.
    @State private var quiet: Double = 0
    @State private var loud: Double = 1
    @State private var isRangeCalibrated = false
    
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
            .background { artworkBackground.ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
        }
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
        .onChange(of: audioPlayer.level) { _, newLevel in
            // Вспышка мгновенная, гаснет плавно — так удары читаются как удары.
            if newLevel > glow {
                glow = newLevel
            } else {
                glow += (newLevel - glow) * 0.06
            }
            
            // Первый замер нового трека задаёт коридор вокруг его реальной громкости.
            // Без этого стартовые 0...1 несколько секунд врут в сторону максимума.
            guard isRangeCalibrated else {
                quiet = max(glow - 0.15, 0)
                loud = min(glow + 0.15, 1)
                isRangeCalibrated = true
                return
            }
            
            // Дальше границы мгновенно раздвигаются наружу и медленно сползают внутрь.
            loud = max(glow, loud + (glow - loud) * 0.004)
            quiet = min(glow, quiet + (glow - quiet) * 0.004)
        }
        .onChange(of: audioPlayer.currentTime) { _, newValue in
            guard !isScrubbing else { return }
            sliderValue = newValue
        }
        .onChange(of: audioPlayer.currentIndex) { _, _ in
            isScrubbing = false
            sliderValue = audioPlayer.currentTime
            
            // У нового трека своя громкость — калибруемся заново.
            isRangeCalibrated = false
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
                } label: {
                    Label("Turn off", systemImage: "xmark")
                }

                Divider()
            }

            Button {
                audioPlayer.stopAfterCurrentTrack()
            } label: {
                Label("End of track", systemImage: "music.note")
            }

            ForEach([15, 30, 45, 60], id: \.self) { minutes in
                Button {
                    audioPlayer.startSleepTimer(minutes: minutes)
                } label: {
                    Label("\(minutes) minutes", systemImage: "clock")
                }
            }
        } label: {
            Label(audioPlayer.hasSleepTimer ? "Sleep timer • on" : "Sleep timer", systemImage: "moon.zzz")
        }
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

    /// Где `glow` находится между тихим и громким местом этого трека, 0...1.
    /// `span` не даёт делить на почти-ноль: на ровном месте фон должен замереть,
    /// а не раздувать микроскопические колебания до полного размаха.
    private var punch: Double {
        let span = max(loud - quiet, 0.12)
        return min(max((glow - quiet) / span, 0), 1)
    }
    
    /// Фон плеера — два цвета обложки. Первый лежит ровным полем и задаёт
    /// настроение трека, второй «дышит» поверх него: разрастается на громком
    /// и опадает на тихом.
    @ViewBuilder
    private var artworkBackground: some View {
        if audioPlayer.currentTrack?.displayArtwork != nil {
            ZStack {
                // Дно: цвета лежат поверх чёрного, иначе на просвет было бы видно
                // то, что под плеером.
                Color.black

                ZStack {
                    // Не заливка одним тоном: к низу цвет отступает, и экран
                    // перестаёт выглядеть куском крашеной бумаги.
                    LinearGradient(
                        colors: [audioPlayer.accent, audioPlayer.accent.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Эллипс, а не круг: он тянется по форме экрана. Радиус задан
                    // долями кадра, поэтому пятно одинаково на любом устройстве.
                    EllipticalGradient(
                        colors: [
                            audioPlayer.secondaryAccent.opacity(0.35 + punch * 0.6),
                            audioPlayer.secondaryAccent.opacity(0)
                        ],
                        center: .center,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.6
                    )
                    .scaleEffect(0.9 + punch * 0.8) // на громком второй цвет наплывает
                    .blur(radius: 40)               // и растворяется в первом
                }
                .saturation(0.9 + punch * 1.1)      // вспыхивает цветом
                .hueRotation(.degrees(punch * 14))  // оттенок ведёт — фон «переливается»

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.9 - punch * 0.7)     // вуаль тончает, цвета проступают
            }
            // Анимация привязана к самим цветам: на смене трека они перетекают
            // друг в друга, а на «дыхании» (оно идёт по `punch`) не срабатывает —
            // иначе каждый удар громкости тянулся бы полсекунды.
            .animation(.easeInOut(duration: 0.6), value: audioPlayer.accent)
            .animation(.easeInOut(duration: 0.6), value: audioPlayer.secondaryAccent)
        } else {
            Color.black
        }
    }
    
    /// Фон под текстом светлый — значит, сам текст должен быть тёмным.
    ///
    /// Раньше ради этого декодировалась обложка, и результат приходилось держать
    /// в `@State`. Теперь фон красит акцент, и яркость считается прямо из него —
    /// пара умножений, их не жалко и на каждой перерисовке.
    private var isLightBackground: Bool {
        guard audioPlayer.currentTrack?.displayArtwork != nil else { return false } // фон чёрный — текст белый

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(audioPlayer.accent).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Веса неравные: глаз сильнее всего реагирует на зелёный, слабее всего на синий.
        return 0.299 * red + 0.587 * green + 0.114 * blue > 0.62
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(max(0, time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
