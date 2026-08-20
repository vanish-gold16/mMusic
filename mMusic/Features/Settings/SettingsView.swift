import SwiftData
import SwiftUI

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer

    @AppStorage(AppSettings.pauseOnDisconnect) private var pauseOnDisconnect = true
    @AppStorage(AppSettings.resumeAfterInterruption) private var resumeAfterInterruption = true
    @AppStorage(AppSettings.playbackRate) private var playbackRate = 1.0
    @AppStorage(AppSettings.deleteOriginalAfterImport) private var deleteOriginalAfterImport = true
    @AppStorage(AppSettings.appearance) private var appearance = Appearance.system.rawValue

    @Query private var tracks: [Track]
    @Query private var albums: [Album]
    @Query private var artists: [Artist]

    /// Файлы в Documents, на которые не ссылается ни один трек. Считаются в `.task`:
    /// это поход в файловую систему, ему не место в `body`.
    @State private var orphanFiles: [String] = []
    @State private var showCleanUpConfirmation = false

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
                        .tint(.orange)
                    }
                }

                Section("library") {
                    LabeledContent("Tracks", value: "\(tracks.count)")
                    LabeledContent("Albums", value: "\(albums.count)")
                    LabeledContent("Artists", value: "\(artists.count)")
                    LabeledContent("Playlists", value: "\(playlistCount)")
                    LabeledContent("Plays", value: "\(totalPlays)")
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
                    Text("Removes leftovers only: artists nothing credits, albums without tracks, and audio files no track points to.")
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
        let known = Set(tracks.map(\.filename))

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: URL.documentsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []

        return contents
            .map(\.lastPathComponent)
            .filter { !known.contains($0) }
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
