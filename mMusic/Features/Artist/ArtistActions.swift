import SwiftData
import SwiftUI

/// Что открывает пункт меню артиста. Как у трека (`TrackAction`), листы
/// и вопросы живут у владельца меню, а не в пунктах.
enum ArtistAction: Hashable, Identifiable {
    case rename
    case photo
    case addToPlaylist
    case radar
    case delete

    var id: Self { self }
}

/// Пункты меню артиста — одни и те же в списке артистов, в поиске и на его
/// странице. Раньше переименовать или удалить артиста можно было только
/// долгим нажатием в списке, а со страницы — нет.
struct ArtistMenuItems: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    let artist: Artist
    /// Его треки в том порядке, в каком их показывает место, где открыли меню.
    let tracks: [Track]
    @Binding var action: ArtistAction?
    /// На его странице запуск и перемешивание — крупные кнопки под именем,
    /// в меню они не повторяются.
    var isOnItsPage = false

    var body: some View {
        if !tracks.isEmpty {
            if !isOnItsPage {
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
            }

            Button {
                action = .addToPlaylist
            } label: {
                Label("Add to a Playlist", systemImage: "text.badge.plus")
            }
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
            action = .rename
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            action = .photo
        } label: {
            Label(artist.artwork == nil ? "Add photo" : "Change photo", systemImage: "photo")
        }

        if artist.artwork != nil {
            Button(role: .destructive) {
                artist.artwork = nil
            } label: {
                Label("Remove photo", systemImage: "person.crop.circle.badge.minus")
            }
        }

        Divider()

        RadarArtistMenuItems(name: artist.name) {
            action = .radar
        }

        Divider()

        Button(role: .destructive) {
            action = .delete
        } label: {
            Label("Remove artist", systemImage: "trash")
        }
    }
}

extension View {

    /// Листы и вопросы для `ArtistMenuItems`.
    ///
    /// `onLeave` — для страницы самого артиста: удалённого (или слитого
    /// с тёзкой) артиста нельзя оставлять на экране, поэтому сначала уходим с него.
    func artistActions(
        _ artist: Artist,
        tracks: [Track],
        action: Binding<ArtistAction?>,
        onLeave: (() -> Void)? = nil
    ) -> some View {
        modifier(ArtistActions(artist: artist, tracks: tracks, action: action, onLeave: onLeave))
    }
}

private struct ArtistActions: ViewModifier {

    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toasts

    let artist: Artist
    let tracks: [Track]
    @Binding var action: ArtistAction?
    let onLeave: (() -> Void)?

    /// Новое имя, пока его набирают в алерте.
    @State private var newName = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: action) { _, action in
                // Алерт открывается с нынешним именем — править проще, чем набирать заново.
                if action == .rename { newName = artist.name }
            }
            .alert("Rename artist", isPresented: isShowing(.rename)) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) { }
                Button("Save") { rename() }
            }
            .sheet(isPresented: isShowing(.photo)) {
                ImagePicker(imageData: photo)
            }
            .sheet(isPresented: isShowing(.addToPlaylist)) {
                AddToPlaylistView(tracks: tracks)
            }
            .radarArtistSheet(name: artist.name, isPresented: isShowing(.radar))
            .confirmationDialog(
                "Remove \"\(artist.name)\"?",
                isPresented: isShowing(.delete),
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    let name = artist.name
                    deleteAfterLeaving(onLeave) {
                        modelContext.delete(artist)
                        toasts.removed("Removed \(name)")
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The name comes off every record and track. The music itself stays in the library.")
            }
    }

    private func isShowing(_ shown: ArtistAction) -> Binding<Bool> {
        Binding(
            get: { action == shown },
            set: { isShown in
                if !isShown, action == shown { action = nil }
            }
        )
    }

    /// Фотография пишется прямо в артиста: выбрал — и она уже на месте.
    private var photo: Binding<Data?> {
        Binding(
            get: { artist.artwork },
            set: { artist.artwork = $0 }
        )
    }

    /// Переименование с оглядкой на дубли: если артист с таким именем уже есть,
    /// вместо второй строки с тем же именем credits переезжают к существующему,
    /// а этот уходит.
    private func rename() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != artist.name else { return }

        let descriptor = FetchDescriptor<Artist>(predicate: #Predicate { $0.name == trimmed })
        guard let existing = try? modelContext.fetch(descriptor).first,
              existing.persistentModelID != artist.persistentModelID
        else {
            artist.name = trimmed
            return
        }

        deleteAfterLeaving(onLeave) {
            // Копия массива: переназначение credit.artist меняет artist.credits по ходу перебора.
            for credit in Array(artist.credits) {
                credit.artist = existing
            }
            modelContext.delete(artist)
            toasts.show("Merged into \(existing.name)", systemImage: "person.2")
        }
    }
}
