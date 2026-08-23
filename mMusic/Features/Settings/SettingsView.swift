import SwiftData
import SwiftUI

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    @AppStorage(AppSettings.pauseOnDisconnect) private var pauseOnDisconnect = true
    @AppStorage(AppSettings.resumeAfterInterruption) private var resumeAfterInterruption = true
    @AppStorage(AppSettings.playbackRate) private var playbackRate = 1.0
    @AppStorage(AppSettings.deleteOriginalAfterImport) private var deleteOriginalAfterImport = true
    @AppStorage(AppSettings.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(AppSettings.birthdayNotifications) private var birthdayNotifications = true

    @Query private var tracks: [Track]
    @Query private var albums: [Album]
    @Query private var artists: [Artist]

    /// Файлы в Documents, на которые не ссылается ни один трек. Считаются в `.task`:
    /// это поход в файловую систему, ему не место в `body`.
    @State private var orphanFiles: [String] = []
    @State private var showCleanUpConfirmation = false
    @State private var isRestoring = false
    @State private var isLinkingAlbums = false
    /// Что нашёл последний проход по альбомам: по нему видно, чего не хватило,
    /// и появляется ли кнопка «собрать альбомы заново».
    @State private var linkReport: LibraryRestore.LinkReport?

    /// Артист остаётся в базе после удаления его последнего трека — credits каскадно
    /// уходят вместе с треком, а сам артист нет.
    private var orphanArtists: [Artist] {
        artists.filter { $0.credits.isEmpty }
    }

    private var emptyAlbums: [Album] {
        albums.filter { $0.tracks.isEmpty }
    }

    private var junkCount: Int {
        orphanArtists.count + emptyAlbums.count + orphanFiles.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Label(option.title, systemImage: option.systemImage)
                                .tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Delete original after import", isOn: $deleteOriginalAfterImport)
                } header: {
                    Text("import")
                } footer: {
                    Text("The file is removed from Files only after it has been copied into the library. Some locations don't allow deleting — those files stay.")
                }

                Section("playback") {
                    Toggle("Pause when headphones disconnect", isOn: $pauseOnDisconnect)
                    Toggle("Resume after a call", isOn: $resumeAfterInterruption)

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Speed")
                            Spacer()
                            Text(String(format: "%.2f×", playbackRate))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $playbackRate, in: 0.5...2.0, step: 0.05) { editing in
                            if !editing { audioPlayer.applyPlaybackRate() }
                        }
                    }
                }

                Section {
                    Toggle("Track birthdays", isOn: $birthdayNotifications)
                } header: {
                    Text("notifications")
                } footer: {
                    Text("On the day a track turns a year older, the app sends a note with how much you have played it. iOS asks for permission the first time there is something to send.")
                }

                Section {
                    NavigationLink {
                        WrappedView()
                    } label: {
                        Label("Your year in music", systemImage: "chart.bar.fill")
                    }
                } header: {
                    Text("stats")
                }

                Section("library") {
                    LabeledContent("Tracks", value: "\(tracks.count)")
                    LabeledContent("Albums", value: "\(albums.count)")
                    LabeledContent("Artists", value: "\(artists.count)")
                    LabeledContent("Playlists", value: "\(playlistCount)")
                    LabeledContent("Plays", value: "\(totalPlays)")

                    // Файлы лежат в песочнице: снесёшь приложение — исчезнут вместе с ним.
                    ShareLink(items: tracks.map { AudioFileStore.url(for: $0.filename) }) {
                        Label("Export all tracks", systemImage: "square.and.arrow.up")
                    }
                    .disabled(tracks.isEmpty)
                }

                if tracksWithoutAlbum > 0 {
                    Section {
                        Button {
                            linkAlbums()
                        } label: {
                            HStack {
                                Label("Link \(tracksWithoutAlbum) tracks to albums", systemImage: "square.stack")
                                if isLinkingAlbums {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isLinkingAlbums)

                        if let linkReport {
                            if linkReport.linked > 0 {
                                LabeledContent("Linked", value: "\(linkReport.linked)")
                            }
                            if !linkReport.missingAlbums.isEmpty {
                                LabeledContent("Albums no longer in the library", value: "\(linkReport.missingAlbums.count)")

                                Button {
                                    linkAlbums(recreatingMissing: true)
                                } label: {
                                    Label("Recreate \(linkReport.missingAlbums.count) albums", systemImage: "square.stack.3d.up")
                                }
                                .disabled(isLinkingAlbums)
                            }
                            if linkReport.withoutName > 0 {
                                LabeledContent("No album name anywhere", value: "\(linkReport.withoutName)")
                            }
                        }
                    } header: {
                        Text("albums")
                    } footer: {
                        Text("Tracks that ended up without an album can be put back into it — the album name comes from the play history or the file tags. Only empty links are filled; the order inside the album has to be fixed by hand. Tracks with no album name anywhere cannot be sorted out automatically: nothing left in the app remembers where they belonged.")
                    }
                }

                if !orphanFiles.isEmpty {
                    Section {
                        Button {
                            restore()
                        } label: {
                            HStack {
                                Label("Restore \(orphanFiles.count) tracks", systemImage: "arrow.clockwise")
                                if isRestoring {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isRestoring)
                    } header: {
                        Text("restore")
                    } footer: {
                        Text("There are audio files in the app that no track points to. They can be put back into the library: the name, artists, album and genre come from the play history, and the date from the file itself. Playlists and favourites cannot be recovered.")
                    }
                }

                Section {
                    LabeledContent("Artists without tracks", value: "\(orphanArtists.count)")
                    LabeledContent("Empty albums", value: "\(emptyAlbums.count)")
                    LabeledContent("Files not in the library", value: "\(orphanFiles.count)")

                    Button(role: .destructive) {
                        showCleanUpConfirmation = true
                    } label: {
                        Label("Clean up", systemImage: "trash")
                    }
                    .disabled(junkCount == 0)
                } header: {
                    Text("clean up")
                } footer: {
                    Text("Removes leftovers only: artists nothing credits, albums without tracks, and audio files no track points to. Deleting the files is final — if they might still be needed, restore them above first.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
            .task {
                orphanFiles = findOrphanFiles()
            }
            // Список пересчитывается после восстановления: треков стало больше,
            // и «ничьих» файлов должно остаться меньше.
            .onChange(of: tracks.count) { _, _ in
                orphanFiles = findOrphanFiles()
            }
            .confirmationDialog(
                "Delete \(junkCount) leftover items?",
                isPresented: $showCleanUpConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clean up", role: .destructive) { cleanUp() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Tracks, albums with tracks and playlists are not touched.")
            }
        }
    }

    private var totalPlays: Int {
        tracks.reduce(0) { $0 + $1.playCount }
    }

    private var playlistCount: Int {
        (try? modelContext.fetchCount(FetchDescriptor<Playlist>())) ?? 0
    }

    /// Всё, что лежит в Documents, минус то, на что ссылаются треки.
    private func findOrphanFiles() -> [String] {
        LibraryRestore.orphanFiles(known: Set(tracks.map(\.filename)))
    }

    /// Треки без альбома. Считается по уже загруженному запросу, без похода в базу.
    private var tracksWithoutAlbum: Int {
        tracks.filter { $0.album == nil }.count
    }

    /// Дозаполняет альбомы у треков, которые остались без них. Отчёт остаётся на
    /// экране: «ничего не вышло» — плохой ответ, когда непонятно, чего не хватило.
    private func linkAlbums(recreatingMissing: Bool = false) {
        isLinkingAlbums = true

        Task { @MainActor in
            let report = await LibraryRestore.linkMissingAlbums(
                in: modelContext,
                recreatingMissing: recreatingMissing
            )
            linkReport = report
            isLinkingAlbums = false

            toasts.show(
                report.linked > 0 ? "Linked \(report.linked) tracks" : "Nothing to link",
                systemImage: "square.stack"
            )
        }
    }

    /// Возвращает в библиотеку файлы, на которые не ссылается ни один трек.
    private func restore() {
        isRestoring = true

        Task { @MainActor in
            let result = await LibraryRestore.restore(orphanFiles, in: modelContext)
            orphanFiles = findOrphanFiles()
            isRestoring = false

            toasts.show(
                result.fromHistory > 0
                    ? "Restored \(result.restored) tracks • \(result.fromHistory) from history"
                    : "Restored \(result.restored) tracks",
                systemImage: "arrow.clockwise"
            )
        }
    }

    private func cleanUp() {
        for filename in orphanFiles {
            AudioFileStore.remove(filename: filename)
        }
        for album in emptyAlbums {
            modelContext.delete(album)
        }
        for artist in orphanArtists {
            modelContext.delete(artist)
        }
        orphanFiles = []
    }
}
