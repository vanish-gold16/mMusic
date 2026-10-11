import SwiftData
import SwiftUI

struct TrackCell: View {
    
    @Environment(AudioPlayer.self) private var audioPlayer

    /// Что открыто из меню строки: лист, вопрос об удалении или переход.
    @State private var action: TrackAction?

    enum LeadingStyle {
        case number
        case artwork
    }

    var track: Track
    var queue: [Track] = []
    var leadingStyle: LeadingStyle = .number
    /// В обычных списках счётчик — лишний шум, поэтому включается точечно.
    var showPlayCount: Bool = false
    /// Длительность справа — там, где список читается как трек-лист со временем,
    /// а не как перечень песен альбома.
    var showDuration: Bool = false
    /// Заполняется только там, где трек показан в составе плейлиста.
    /// Без него в меню нет и пункта — удалять «из плейлиста» на странице альбома нечего.
    var onRemoveFromPlaylist: (() -> Void)?
    /// Трек запущен нажатием на строку. Нужен плейлисту: запуск с любой его песни —
    /// тоже запуск плейлиста, и по нему плейлисты выстраиваются в библиотеке.
    var onPlay: (() -> Void)?
    /// Своя подпись вместо номера трека — на странице альбома это «A1», «B2»,
    /// как на обороте пластинки.
    var number: String?
    /// На странице альбома авторы у всех треков одни и те же, и они уже
    /// написаны в шапке. Под именем остаются только приглашённые.
    var showsOnlyGuests = false
    /// Страница, на которой стоит строка: её меню туда не ведёт.
    var currentPage: MusicRoute? = nil

    /// Строка под именем трека. Пустая — строки нет совсем.
    private var subtitle: String {
        guard showsOnlyGuests else {
            return track.artistNames.joined(separator: ", ")
        }

        let hosts = Set(track.album?.artistNames ?? [])
        let guests = track.credits
            .sorted { $0.position < $1.position }
            .filter { !hosts.contains($0.artist.name) }
        guard !guests.isEmpty else { return "" }

        let names = guests.map(\.artist.name).joined(separator: ", ")
        return guests.allSatisfy { $0.role == .featured } ? "feat. \(names)" : names
    }

    private var isCurrent: Bool {
        audioPlayer.currentTrack?.id == track.id
    }

    var body: some View {
        HStack {
            switch leadingStyle {
            case .number:
                if isCurrent {
                    EqualizerView(level: audioPlayer.level)
                        .foregroundStyle(.tint)
                        .frame(width: 40, height: 40)
                } else {
                    Text(number ?? "\(track.position + 1)")
                        .monospacedDigit()
                        .frame(width: 40, height: 40)
                }
            case .artwork:
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
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
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            VStack(alignment: .leading) {
                Text(track.name)
                    .bold()
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()

            if track.isFavourite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }

            if showPlayCount, track.playCount > 0 {
                Label("\(track.playCount)", systemImage: "play.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                    .monospacedDigit()
            }

            if showDuration, track.duration > 0 {
                Text(Duration.seconds(track.duration).formatted(.time(pattern: .minuteSecond)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        // Играющая строка красится стеклом, а не отдельной плашкой: видно сразу,
        // и цвет тот же, что у обложки.
        .glassEffect(isCurrent ? .regular.tint(audioPlayer.accent.opacity(0.28)) : .regular)
        // Превью меню той же формы, что и стекло, — без него система
        // вырезает прямоугольник с острыми углами.
        .contentShape(.contextMenuPreview, Capsule())
        // Долгое нажатие на строку — то же меню, что за «…»: искать маленькую
        // кнопку в конце строки, чтобы дойти до альбома, незачем.
        .contextMenu {
            menuItems
        }
        .padding(.horizontal)
        .onTapGesture {
            let list = queue.isEmpty ? [track] : queue  // ← подумай, не перепутал ли порядок
            let index = list.firstIndex { $0.id == track.id } ?? 0
            audioPlayer.play(list, startingAt: index)
            onPlay?()
        }
        .trackActions(track, action: $action)
    }

    private var menuItems: some View {
        TrackMenuItems(
            track: track,
            action: $action,
            onRemoveFromPlaylist: onRemoveFromPlaylist,
            currentPage: currentPage
        )
    }
}
