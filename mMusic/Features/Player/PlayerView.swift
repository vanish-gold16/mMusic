import SwiftUI

struct PlayerView: View {
    let audioPlayer: AudioPlayer
    
    @State private var sliderValue: TimeInterval = 0
    @State private var isScrubbing = false
    @State private var isQueuePresented = false
    @State private var isAddingToPlaylist = false
    @State private var isEditingTrack = false
    
    /// Сглаженная громкость для фона: тянется за `audioPlayer.level`, но лениво,
    /// иначе фон мигал бы на каждой ноте.
    @State private var glow: Double = 0
    @State private var artworkWidth: CGFloat = 0

    /// Обложка светлая — значит, текст поверх неё должен быть тёмным.
    /// Считается один раз на трек в `.task`: `body` пересобирается десятки раз
    /// в секунду вслед за `glow`, там такому расчёту не место.
    @State private var isLightBackground = false

    /// Ползучие границы громкости этого трека — подстраиваются сами,
    /// чтобы фон одинаково хорошо дышал и на тихой записи, и на громкой.
    @State private var quiet: Double = 0
    @State private var loud: Double = 1
    @State private var isRangeCalibrated = false
    
    var body: some View {
        // Стек нужен ради перехода на артиста: лист сам по себе навигации не имеет.
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDragIndicator(.visible)
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
        .presentationBackground { artworkBackground }
        // Ставится последним, поэтому накрывает и контент, и фон шторки: на светлой
        // обложке вуаль становится светлой, а `.primary` / `.secondary` — тёмными.
        .environment(\.colorScheme, isLightBackground ? .light : .dark)
        .onAppear { sliderValue = audioPlayer.currentTime }
        .task(id: audioPlayer.currentTrack?.filename) {
            isLightBackground = await Self.isLight(artwork: audioPlayer.currentTrack?.displayArtwork)

            // Фоновый проход идёт по всей библиотеке подряд; тот трек, что открыт
            // прямо сейчас, ждать своей очереди не должен.
            if let track = audioPlayer.currentTrack {
                await TrackWaveformLoader.fill(track)
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

            outputRow

            Spacer()

            bottomRow
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
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

    /// Громкость и выбор устройства — системные вьюхи: своих аналогов iOS не разрешает.
    private var outputRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            SystemVolumeSlider(tint: UIColor(audioPlayer.accent))
                .frame(height: 28)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(.secondary)
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
    
    @ViewBuilder
    private var artworkBackground: some View {
        if let data = audioPlayer.currentTrack?.displayArtwork,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 60)                  // константа — пересчитывается один раз
                .scaleEffect(1.25 + punch * 0.45)  // на громком фон наплывает
                .clipped()
                .saturation(0.9 + punch * 1.6)     // и вспыхивает цветом
                .brightness(punch * 0.12)
                .hueRotation(.degrees(punch * 18)) // оттенок ведёт — фон «переливается»
                .overlay {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.9 - punch * 0.7) // вуаль тончает, обложка проступает
                }
        } else {
            Color.black
        }
    }
    
    /// Декодирование обложки — не мгновенная операция, уводим её с главного потока.
    /// Порог 0.6, а не 0.5: под текстом лежит не сама обложка, а её размытая
    /// и подсвеченная версия — она заметно светлее оригинала.
    private static func isLight(artwork data: Data?) async -> Bool {
        guard let data else { return false }   // нет обложки — фон чёрный, текст белый

        return await Task.detached(priority: .utility) {
            guard let brightness = UIImage(data: data)?.averageBrightness else { return false }
            return brightness > 0.6
        }.value
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(max(0, time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
