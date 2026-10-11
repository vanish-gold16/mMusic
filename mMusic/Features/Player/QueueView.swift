import SwiftUI

/// Что играет сейчас и что дальше. Список — это ровно `audioPlayer.queue`,
/// поэтому перестановка и удаление здесь сразу меняют воспроизведение.
///
/// Шапка — как у страниц приложения: «Queue» сжатым шрифтом, паспорт «сколько
/// впереди и сколько осталось», под ними выключатели с лампами — те же подписи,
/// что на панели плеера под клавишами.
struct QueueView: View {

    let audioPlayer: AudioPlayer
    /// Переход к альбому или артисту из меню строки. Своей стопки у листа
    /// нет — экран открывает плеер.
    let onOpen: (MusicRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts

    private var upcomingCount: Int {
        max(audioPlayer.queue.count - audioPlayer.currentIndex - 1, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if audioPlayer.queue.isEmpty {
                Text("Play an album or a playlist to fill it")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        let accent = audioPlayer.accent

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Queue")
                    .font(.system(size: 34, weight: .heavy).width(.compressed))

                Spacer()

                SheetActionButton(.close) { dismiss() }
            }

            QueuePassport(audioPlayer: audioPlayer, upcomingCount: upcomingCount)

            // Режимы — выключатели с лампами, как «TEXT» и «REMIX» под клавишами
            // плеера: горит — включено. «Clear» лампы не имеет: он ничего
            // не включает, а только делает.
            HStack(spacing: 18) {
                PanelSwitch(title: "Shuffle", isOn: audioPlayer.isShuffled, accent: accent) {
                    audioPlayer.toggleShuffle()
                }

                PanelSwitch(title: repeatTitle, isOn: audioPlayer.repeatMode.isActive, accent: accent) {
                    audioPlayer.cycleRepeatMode()
                }

                Spacer(minLength: 0)

                PanelSwitch(title: "Clear", accent: accent) {
                    let removed = upcomingCount
                    audioPlayer.clearUpcoming()
                    toasts.removed(removed == 1 ? "1 track removed" : "\(removed) tracks removed")
                }
                .disabled(upcomingCount == 0)
                .opacity(upcomingCount == 0 ? 0.4 : 1)
                .accessibilityLabel("Clear what plays next")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    /// Подпись повтора говорит, что именно повторяется, — лампа говорит только «вкл».
    private var repeatTitle: String {
        switch audioPlayer.repeatMode {
        case .off: "Repeat"
        case .all: "Repeat all"
        case .one: "Repeat one"
        }
    }

    /// Индексы, а не сами треки: один и тот же трек может стоять в очереди дважды,
    /// а `jump(to:)` и перестановка работают именно с позицией.
    private var list: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(audioPlayer.queue.enumerated()), id: \.offset) { index, track in
                    QueueRow(audioPlayer: audioPlayer, track: track, index: index, onOpen: onOpen)
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
}

/// Строка очереди. Отдельный вид ради своего меню: у каждой строки свои
/// листы и вопрос об удалении (`trackActions`), а `@State` живёт только у вида.
private struct QueueRow: View {

    let audioPlayer: AudioPlayer
    let track: Track
    /// Место в очереди, а не сам трек: один и тот же трек может стоять дважды.
    let index: Int
    let onOpen: (MusicRoute) -> Void

    @State private var action: TrackAction?

    var body: some View {
        let isCurrent = index == audioPlayer.currentIndex
        // Сыгранное не прячем — к нему возвращаются, — но и внимание на себя
        // тянуть оно не должно.
        let isPlayed = index < audioPlayer.currentIndex

        HStack(spacing: 12) {
            PickCover(track: track, side: 46)
                .overlay {
                    if isCurrent {
                        Color.black.opacity(0.45)
                        QueueBars(audioPlayer: audioPlayer)
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? audioPlayer.accent : Color.primary)

                if !track.artistNames.isEmpty {
                    Text(track.artistNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
        .contextMenu {
            menu(isCurrent: isCurrent)
        }
        .trackActions(track, action: $action, onNavigate: onOpen)
    }

    /// Сверху — то, что делают именно в очереди: переставить трек следующим
    /// или убрать. Ниже — обычное меню трека, без «Play next / Play after»:
    /// здесь они ставили бы в очередь второй экземпляр того же трека.
    @ViewBuilder
    private func menu(isCurrent: Bool) -> some View {
        if !isCurrent {
            if index != audioPlayer.currentIndex + 1 {
                Button {
                    audioPlayer.moveInQueue(from: IndexSet(integer: index), to: audioPlayer.currentIndex + 1)
                } label: {
                    Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
            }

            // Играющий трек отсюда не убирается: музыка бы встала посреди песни.
            // Для этого есть смахивание строки.
            Button(role: .destructive) {
                audioPlayer.removeFromQueue(at: IndexSet(integer: index))
            } label: {
                Label("Remove from queue", systemImage: "minus.circle")
            }

            Divider()
        }

        TrackMenuItems(track: track, action: $action, showsEnqueue: false)
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(max(0, time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// «12 TRACKS NEXT  ·  47 MIN LEFT». Время читается здесь, а не в самой
/// очереди: оно меняется пять раз в секунду, и перерисовываться на каждый тик
/// должна одна строка, а не весь список.
private struct QueuePassport: View {

    let audioPlayer: AudioPlayer
    let upcomingCount: Int

    /// Сколько ещё играть с текущего трека до конца очереди.
    private var timeLeft: TimeInterval {
        guard audioPlayer.queue.indices.contains(audioPlayer.currentIndex) else { return 0 }

        let upcoming = audioPlayer.queue[audioPlayer.currentIndex...].reduce(0) { $0 + $1.duration }
        return max(upcoming - audioPlayer.currentTime, 0)
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(1.2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    private var text: String {
        guard !audioPlayer.queue.isEmpty else { return "NOTHING LINED UP" }

        let tracks = upcomingCount == 0
            ? "LAST TRACK"
            : (upcomingCount == 1 ? "1 TRACK NEXT" : "\(upcomingCount) TRACKS NEXT")
        let left = timeLeft

        guard left > 0 else { return tracks }
        return "\(tracks)  ·  \(Self.minutes(left)) LEFT"
    }

    private static func minutes(_ time: TimeInterval) -> String {
        let minutes = Int((time / 60).rounded())
        guard minutes >= 60 else { return "\(max(minutes, 1)) MIN" }

        return "\(minutes / 60) H \(minutes % 60) MIN"
    }
}

/// Полоски на обложке играющего трека. Громкость читается здесь: она меняется
/// 30 раз в секунду, и перерисовываться должны полоски, а не вся очередь.
private struct QueueBars: View {

    let audioPlayer: AudioPlayer

    var body: some View {
        EqualizerView(level: audioPlayer.level)
    }
}
