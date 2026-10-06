import SwiftUI

/// Мини-плеер над вкладками — маленькая дека.
///
/// Слева конверт играющей пластинки, из-за которого выглядывает диск: пока
/// музыка идёт, он крутится, как пластинки в сетке альбомов. Посередине сжатое
/// имя трека, артист и звуковая дорожка трека, где сыгранное горит цветом
/// обложки, — та же лента, что под головкой в большом плеере, только целиком.
/// Справа клавиши; у «пуска» лампа, как на деке: горит — играет.
///
/// Нажатие на конверт или имя открывает плеер: обложка вырастает в его обложку.
struct MiniPlayerView: View {
    let audioPlayer: AudioPlayer
    let namespace: Namespace.ID

    @Binding var isPlayerPresented: Bool

    /// Свёрнутые вкладки оставляют мини-плееру узкую полоску — тогда только
    /// конверт, имя и «пуск».
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    /// Уменьшенная обложка — декодируется в `.task`, а не в `body`:
    /// полноразмерная весит мегабайты.
    @State private var cover: UIImage?

    private var isInline: Bool { placement == .inline }

    var body: some View {
        if let track = audioPlayer.currentTrack {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    sleeve
                    titleBlock(track)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        isPlayerPresented = true
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens the player")

                keys
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .frame(maxHeight: .infinity)
            .task(id: track.displayArtwork?.count) {
                await loadCover(track.displayArtwork)
            }
        }
    }

    // MARK: - Конверт

    /// Обложка и диск за ней. Диск выглядывает вправо и крутится, пока играет.
    /// Переход в плеер привязан только к обложке: диск остаётся здесь.
    private var sleeve: some View {
        let side: CGFloat = isInline ? 26 : 34

        return ZStack(alignment: .leading) {
            VinylRecord(
                cover: cover,
                durations: [],
                currentIndex: nil,
                progress: nil,
                isSpinning: audioPlayer.isPlaying,
                rpm: Album.AlbumType.LP.rpm,
                labelFraction: 0.42,
                accent: audioPlayer.accent,
                onTapTrack: nil
            )
            .frame(width: side * 0.92, height: side * 0.92)
            .offset(x: side * 0.42)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(.systemGray5))
                .overlay {
                    if let cover {
                        Image(uiImage: cover)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .frame(width: side, height: side)
                // Источник геометрии, пока плеер закрыт: отсюда обложка растёт.
                .matchedGeometryEffect(id: PlayerTransition.artwork, in: namespace, isSource: !isPlayerPresented)
                .shadow(color: .black.opacity(0.25), radius: 3, x: 1, y: 1)
        }
        .frame(width: side * 1.34, height: side, alignment: .leading)
        .accessibilityHidden(true)
    }

    // MARK: - Имя

    private func titleBlock(_ track: Track) -> some View {
        VStack(alignment: .leading, spacing: isInline ? 0 : 3) {
            // Артист на той же строке, что имя, — вторая строка отдана ленте.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(track.name)
                    .font(.system(size: 17, weight: .heavy).width(.compressed))
                    .lineLimit(1)
                    .layoutPriority(1)

                if !isInline {
                    Text(track.artistNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if !isInline {
                MiniTape(audioPlayer: audioPlayer, samples: track.waveform.map(Array.init) ?? [])
                    .frame(height: 10)
            }
        }
    }

    // MARK: - Клавиши

    private var keys: some View {
        HStack(spacing: 2) {
            if !isInline {
                key("backward.fill", title: "Previous") {
                    audioPlayer.playPrevious()
                }
            }

            key(
                audioPlayer.isPlaying ? "pause.fill" : "play.fill",
                title: audioPlayer.isPlaying ? "Pause" : "Play",
                lamp: audioPlayer.isPlaying,
                isMain: true
            ) {
                audioPlayer.togglePlayPause()
            }

            if !isInline {
                key("forward.fill", title: "Next") {
                    audioPlayer.playNext()
                }
            }
        }
    }

    /// Клавиша без своего стекла — стекло здесь уже у всей полоски. Лампа,
    /// если есть, — та же, что у клавиш деки, только меньше. «Пуск» крупнее
    /// остальных, как на деке.
    private func key(
        _ systemImage: String,
        title: String,
        lamp: Bool? = nil,
        isMain: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(isMain ? .title3 : .body.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 36, height: 36)
                .overlay(alignment: .top) {
                    if let lamp {
                        DeckLamp(isOn: lamp, accent: audioPlayer.accent)
                            .scaleEffect(0.75)
                            .offset(y: -1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(MiniKeyStyle())
        .foregroundStyle(.primary)
        .accessibilityLabel(title)
    }

    /// Обложка здесь 34 pt — около 100 px на экране @3x; с запасом под диск.
    private func loadCover(_ data: Data?) async {
        guard let data else {
            cover = nil
            return
        }

        let image = await Task.detached(priority: .utility) {
            UIImage.thumbnail(from: data, side: 160)
        }.value

        guard !Task.isCancelled else { return }
        cover = image
    }
}

/// Клавиша проседает под пальцем, как у деки, а не исчезает.
private struct MiniKeyStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Весь трек одной короткой дорожкой: столбики громкости, сыгранные — цветом
/// обложки. Время читается здесь, а не в мини-плеере: оно меняется пять раз
/// в секунду, и перерисовываться должна только дорожка.
private struct MiniTape: View {

    let audioPlayer: AudioPlayer
    /// Форма волны трека (`Track.waveform`). Пусто — ещё не посчитана,
    /// тогда дорожка ровная.
    let samples: [UInt8]

    private let step: CGFloat = 3
    private let barWidth: CGFloat = 2

    var body: some View {
        let progress = audioPlayer.duration > 0 ? audioPlayer.currentTime / audioPlayer.duration : 0
        let accent = audioPlayer.accent

        Canvas { context, size in
            let count = max(Int(size.width / step), 1)
            let played = Int((Double(count) * min(max(progress, 0), 1)).rounded())

            for bar in 0..<count {
                let level: CGFloat
                if samples.isEmpty {
                    level = 0.25
                } else {
                    let index = min(bar * samples.count / count, samples.count - 1)
                    level = CGFloat(samples[index]) / 255
                }

                let height = max(2, level * size.height)
                let rect = CGRect(x: CGFloat(bar) * step, y: (size.height - height) / 2, width: barWidth, height: height)
                let color = bar < played ? accent : Color.primary.opacity(0.2)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}
