import SwiftUI

/// Что играет сейчас и что дальше. Список — это ровно `audioPlayer.queue`,
/// поэтому перестановка и удаление здесь сразу меняют воспроизведение.
struct QueueView: View {

    let audioPlayer: AudioPlayer

    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts

    /// Сколько ещё играть с текущего трека до конца очереди.
    private var timeLeft: TimeInterval {
        guard audioPlayer.queue.indices.contains(audioPlayer.currentIndex) else { return 0 }

        let upcoming = audioPlayer.queue[audioPlayer.currentIndex...].reduce(0) { $0 + $1.duration }
        return max(upcoming - audioPlayer.currentTime, 0)
    }

    private var upcomingCount: Int {
        max(audioPlayer.queue.count - audioPlayer.currentIndex - 1, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if audioPlayer.queue.isEmpty {
                ContentUnavailableView(
                    "Queue is empty",
                    systemImage: "music.note.list",
                    description: Text("Play an album or a playlist to fill it.")
                )
                .frame(maxHeight: .infinity)
            } else {
                list
            }
        }
        // Лист наполовину — очередь смотрят мельком, а не изучают.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // Фон стеклянный: сквозь него виден цвет плеера, и лист не выглядит
        // вырезанным из другого приложения.
        .presentationBackground(.regularMaterial)
    }

    /// Свой заголовок вместо навигационной панели: строка состояния очереди
    /// («сколько ещё играть») здесь полезнее, чем слово «Queue» по центру.
    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Queue")
                        .font(.title3.bold())

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                Button("Done") { dismiss() }
                    .font(.subheadline.weight(.semibold))
            }

            HStack(spacing: 10) {
                toggle("shuffle", title: "Shuffle", isOn: audioPlayer.isShuffled) {
                    audioPlayer.toggleShuffle()
                }

                toggle(
                    audioPlayer.repeatMode.systemImage,
                    title: audioPlayer.repeatMode.title,
                    isOn: audioPlayer.repeatMode.isActive
                ) {
                    audioPlayer.cycleRepeatMode()
                }

                Spacer()

                Button {
                    let removed = upcomingCount
                    audioPlayer.clearUpcoming()
                    toasts.removed(removed == 1 ? "1 track removed" : "\(removed) tracks removed")
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .disabled(upcomingCount == 0)
                .opacity(upcomingCount == 0 ? 0.4 : 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var subtitle: String {
        guard !audioPlayer.queue.isEmpty else { return "nothing lined up" }

        let tracks = upcomingCount == 1 ? "1 track next" : "\(upcomingCount) tracks next"
        return timeLeft > 0 ? "\(tracks) • \(minutesString(timeLeft)) left" : tracks
    }

    /// Круглые тумблеры режимов: включённый заливается цветом обложки —
    /// то же правило, что у кнопок в плеере.
    private func toggle(
        _ systemImage: String,
        title: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .labelStyle(.iconOnly)
                .frame(width: 36, height: 36)
                .foregroundStyle(isOn ? audioPlayer.accent : Color.secondary)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isOn ? .regular.tint(audioPlayer.accent.opacity(0.25)).interactive() : .regular.interactive(),
            in: .circle
        )
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "on" : "off")
    }

    /// Индексы, а не сами треки: один и тот же трек может стоять в очереди дважды,
    /// а `jump(to:)` и перестановка работают именно с позицией.
    private var list: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(audioPlayer.queue.enumerated()), id: \.offset) { index, track in
                    row(for: track, at: index)
                        .id(index)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onTapGesture { audioPlayer.jump(to: index) }
                }
                .onMove { source, destination in
                    audioPlayer.moveInQueue(from: source, to: destination)
                }
                .onDelete { offsets in
                    audioPlayer.removeFromQueue(at: offsets)
                }
            }
            .listStyle(.plain)
            // Список едет поверх стекла, поэтому своя подложка ему не нужна.
            .scrollContentBackground(.hidden)
            .onAppear {
                // Открываем очередь там, где она сейчас звучит, а не на первом треке.
                proxy.scrollTo(audioPlayer.currentIndex, anchor: .center)
            }
        }
    }

    private func row(for track: Track, at index: Int) -> some View {
        let isCurrent = index == audioPlayer.currentIndex
        // Сыгранное не прячем — к нему возвращаются, — но и внимание на себя
        // тянуть оно не должно.
        let isPlayed = index < audioPlayer.currentIndex

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 46, height: 46)
                .overlay {
                    if let data = track.displayArtwork, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay {
                    if isCurrent {
                        Color.black.opacity(0.45)
                        EqualizerView(level: audioPlayer.level)
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? audioPlayer.accent : Color.primary)

                Text(track.artistNames.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if track.duration > 0 {
                Text(timeString(track.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // Играющая строка подсвечивается стеклом с цветом обложки — так же,
        // как в списках библиотеки.
        .glassEffect(isCurrent ? .regular.tint(audioPlayer.accent.opacity(0.28)) : .identity)
        .opacity(isPlayed ? 0.45 : 1)
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(max(0, time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func minutesString(_ time: TimeInterval) -> String {
        let minutes = Int((time / 60).rounded())
        guard minutes >= 60 else { return "\(max(minutes, 1)) min" }

        return "\(minutes / 60) h \(minutes % 60) min"
    }
}
