import SwiftUI

/// Трек внутри собираемого альбома: имя крупно в шапке, авторы и жанр —
/// разделами, как в форме нового трека. Авторы альбома стоят приглушёнными
/// впереди: они у трека и так есть, здесь добавляют только гостей.
///
/// Если в файле узнан сингл из библиотеки, в альбом переедет сам сингл, а не
/// этот файл, — поля тогда приглушены: править нечего, трек уже есть.
struct TrackDraftEditView: View {

    @Binding var draft: TrackDraft

    var albumArtists: [String] = []
    /// Трек библиотеки, который переедет вместо файла. nil — файл станет новым треком.
    var existing: Track?

    private var isMovingIn: Bool { draft.existingTrack != nil && existing != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isMovingIn, let existing {
                    alreadyInLibrary(existing)
                }

                VStack(alignment: .leading, spacing: 24) {
                    RecordTitleField(placeholder: "Track name", text: $draft.name)
                        .padding(.horizontal)

                    RecordFormSection("Artists") {
                        VStack(alignment: .leading, spacing: 10) {
                            ArtistsEditor(artists: $draft.artists, readOnlyArtists: albumArtists)
                            RecordHint("Tap a name to mark a guest")
                        }
                        .padding(.horizontal)
                    }

                    RecordFormSection("Genre") {
                        GenreMenu(genre: $draft.genre)
                            .padding(.horizontal)
                    }
                }
                .disabled(isMovingIn)
                .opacity(isMovingIn ? 0.4 : 1)
            }
            .padding(.vertical)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Что произойдёт с треком и как от этого отказаться. Отказ — для случая,
    /// когда совпадение ошибочное или нужна именно альбомная версия файла.
    private func alreadyInLibrary(_ track: Track) -> some View {
        RecordFormSection("Already in library") {
            VStack(alignment: .leading, spacing: 12) {
                Text(explanation(for: track))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                DashedSlot(title: "Import this file as a new track") {
                    withAnimation(.snappy) { draft.existingTrack = nil }
                }
            }
            .padding(.horizontal)
        }
    }

    private func explanation(for track: Track) -> String {
        // Сингл обычно называется так же, как песня, — тогда имя второй раз не нужно.
        let place = switch track.album?.name {
        case nil: "a track without an album"
        case track.name: "a single"
        case let name?: "the single \(name)"
        }
        return "\(track.name) is already here as \(place). It moves into this album with its plays, star, playlists and cover. This file won't be imported."
    }
}
