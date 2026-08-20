import SwiftUI

/// Что играет сейчас и что дальше. Список — это ровно `audioPlayer.queue`,
/// поэтому перестановка и удаление здесь сразу меняют воспроизведение.
struct QueueView: View {

    let audioPlayer: AudioPlayer

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if audioPlayer.queue.isEmpty {
                    ContentUnavailableView(
                        "Queue is empty",
                        systemImage: "music.note.list",
                        description: Text("Play an album or a playlist to fill it.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        audioPlayer.toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .tint(audioPlayer.isShuffled ? audioPlayer.accent : Color.secondary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        audioPlayer.cycleRepeatMode()
                    } label: {
                        Image(systemName: audioPlayer.repeatMode.systemImage)
                    }
                    .tint(audioPlayer.repeatMode.isActive ? audioPlayer.accent : Color.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
        }
    }

    /// Индексы, а не сами треки: один и тот же трек может стоять в очереди дважды,
    /// а `jump(to:)` и перестановка работают именно с позицией.
    private var list: some View {
        List {
            ForEach(Array(audioPlayer.queue.enumerated()), id: \.offset) { index, track in
                row(for: track, at: index)
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
    }

    private func row(for track: Track, at index: Int) -> some View {
        let isCurrent = index == audioPlayer.currentIndex

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 44, height: 44)
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
                        Color.black.opacity(0.4)
                        EqualizerView(level: audioPlayer.level)
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
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
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(max(0, time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
