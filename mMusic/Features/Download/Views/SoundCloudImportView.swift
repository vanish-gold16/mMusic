import SwiftUI

/// Забирает трек с SoundCloud и отдаёт готовый файл наружу — правит его дальше
/// обычная форма импорта, чтобы не заводить второй экран с теми же полями.
struct SoundCloudImportView: View {

    let onReady: (PickedFile, AudioMetadata) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var link = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var canStart: Bool {
        !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("https://soundcloud.com/…", text: $link)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(isWorking)

                        Button {
                            link = UIPasteboard.general.string ?? link
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .disabled(isWorking)
                    }
                } header: {
                    Text("track link")
                } footer: {
                    Text("Paste the address of a single track — a profile or a playlist link won't work.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await start() }
                    } label: {
                        HStack {
                            if isWorking {
                                ProgressView()
                                Text("Downloading…")
                            } else {
                                Text("Download")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!canStart)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("From SoundCloud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .disabled(isWorking)
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    private func start() async {
        isWorking = true
        errorMessage = nil

        do {
            let track = try await SoundCloudClient.resolve(link)
            let file = try await SoundCloudClient.download(track)
            let artwork = await SoundCloudClient.artworkData(for: track)

            let metadata = AudioMetadata(
                title: track.title,
                artist: track.artist,
                albumName: nil,
                artwork: artwork
            )

            onReady(PickedFile(url: file), metadata)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
    }
}
