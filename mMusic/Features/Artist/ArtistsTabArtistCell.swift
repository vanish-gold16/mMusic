import SwiftData
import SwiftUI

/// Строка артиста в библиотеке и поиске — уменьшенная шапка его страницы:
/// та же пластинка с его релизами кольцами, сжатое имя и строка пластинок.
/// Играет его трек — на диске горит кольцо играющей пластинки, а справа
/// пляшут полоски, как у играющей пластинки в стопке на главной.
struct ArtistsTabArtistCell: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    @State private var showDeleteConfirmation = false
    @State private var showRename = false
    @State private var newName = ""

    /// Уменьшенная фотография и цвет бумажного яблока. Считаются в `.task`,
    /// а не в `body`: фотография и обложка весят мегабайты.
    @State private var photo: UIImage?
    @State private var labelPaper: Color?

    var artist: Artist

    var body: some View {
        let discography = ArtistDiscography(artist: artist)
        let isPlayingArtist = audioPlayer.isPlaying
            && audioPlayer.currentTrack?.artists.contains { $0.persistentModelID == artist.persistentModelID } == true

        NavigationLink {
            ArtistView(artist: artist)
        } label: {
            HStack(spacing: 14) {
                ArtistDisc(
                    name: artist.name,
                    releases: discography.career,
                    photo: photo,
                    labelPaper: labelPaper,
                    accent: audioPlayer.accent
                )
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text(artist.name)
                        .font(.system(size: 24, weight: .heavy).width(.compressed))
                        .lineLimit(1)

                    Text(discography.recordsSummary ?? "NO RECORDS YET")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isPlayingArtist {
                    PlayingBars()
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Playing")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            menu(tracks: discography.tracks)
        }
        .task(id: [artist.artwork?.count, discography.newestCover?.count]) {
            await loadLabel(cover: discography.newestCover)
        }
        .alert("Rename artist", isPresented: $showRename) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Save") { rename() }
        }
        .confirmationDialog(
            "Remove \"\(artist.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                modelContext.delete(artist)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This artist will be permanently deleted.")
        }
    }

    @ViewBuilder
    private func menu(tracks: [Track]) -> some View {
        if !tracks.isEmpty {
            Button {
                audioPlayer.play(tracks)
            } label: {
                Label("Play", systemImage: "play")
            }
            Button {
                audioPlayer.playShuffled(tracks)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
            }

            Divider()

            Button {
                audioPlayer.enqueueNext(tracks)
                toasts.enqueuedNext(tracks.count)
            } label: {
                Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button {
                audioPlayer.enqueueLast(tracks)
                toasts.enqueuedLast(tracks.count)
            } label: {
                Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
            }

            Divider()
        }

        Button {
            newName = artist.name
            showRename = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    /// Яблоко здесь около 30 pt — 90 px на экране @3x. Без фотографии
    /// с обложки нужен только цвет, и её хватает совсем маленькой.
    private func loadLabel(cover: Data?) async {
        let photoData = artist.artwork

        let (image, palette) = await Task.detached(priority: .utility) {
            if let photoData {
                return (UIImage.thumbnail(from: photoData, side: 180), nil as CoverPalette?)
            }
            return (nil as UIImage?, cover.flatMap { UIImage.thumbnail(from: $0, side: 100) }?.coverPalette)
        }.value

        guard !Task.isCancelled else { return }

        photo = image
        labelPaper = palette?.accent
    }

    /// Переименование с оглядкой на дубли: если артист с таким именем уже есть,
    /// вместо второй строки с тем же именем его credits переезжают к существующему.
    private func rename() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != artist.name else { return }

        let descriptor = FetchDescriptor<Artist>(predicate: #Predicate { $0.name == trimmed })
        if let existing = try? modelContext.fetch(descriptor).first,
           existing.persistentModelID != artist.persistentModelID {
            // Копия массива: переназначение credit.artist меняет artist.credits по ходу перебора.
            for credit in Array(artist.credits) {
                credit.artist = existing
            }
            modelContext.delete(artist)
            return
        }

        artist.name = trimmed
    }
}

/// Полоски играющего артиста. Громкость читается здесь: она меняется 30 раз
/// в секунду, и перерисовываться должны полоски, а не вся строка.
private struct PlayingBars: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    var body: some View {
        EqualizerView(level: audioPlayer.level, barCount: 4, maxHeight: 14)
    }
}
