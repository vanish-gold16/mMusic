import SwiftData
import SwiftUI

struct EditTrackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var track: Track
    
    @State private var showImagePicker = false
    @State private var showLyricsEditor = false
    
    @State private var drafts: [ArtistDraft] = []

    private var hasRelease: Binding<Bool> {
        Binding(
            get: { track.album?.release != nil },
            set: { track.album?.release = $0 ? .now : nil }
        )
    }

    private var releaseDate: Binding<Date> {
        Binding(
            get: { track.album?.release ?? .now },
            set: { track.album?.release = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    if let artworkData = track.displayArtwork, let uiImage = UIImage(data: artworkData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "music.note")
                            }
                            .scaledToFit()
                            .frame(height: 150)
                    }
                    
                    // Пока трек в альбоме, обложка у него альбомная — своя всё
                    // равно не покажется, и предлагать её выбрать было бы
                    // обманом. Выбранная раньше никуда не делась: она вернётся,
                    // если трек выйдет из альбома или у альбома не станет обложки.
                    if let album = track.album, album.artwork != nil {
                        Text("Cover comes from \"\(album.name)\"")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("Pick an image", systemImage: "photo")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(imageData: $track.artwork)
                }
                
                Form {
                    Section("name") {
                        TextField(track.name, text: $track.name)
                    }
                    Section("artist") {
                        ArtistsEditor(
                            artists: $drafts,
                            readOnlyArtists: track.album?.artists.map(\.name) ?? []
                        )
                    }
                    Section() {
                        Picker("genre", selection: $track.genre) {
                            ForEach(Genre.allCases, id: \.self) { genre in
                                Text(genre.rawValue).tag(genre)
                            }
                        }
                    }
                    Section("text") {
                        Button {
                            showLyricsEditor = true
                        } label: {
                            HStack {
                                Label(track.hasLyrics ? "edit text" : "add text", systemImage: "quote.bubble")
                                Spacer()
                                // Первая строка вместо «есть / нет»: по ней сразу
                                // видно, тот ли это текст.
                                if let firstLine = track.lyrics?.split(separator: "\n").first {
                                    Text(firstLine)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    Section("release") {
                        Toggle("has release date", isOn: hasRelease)
                        if track.album?.release != nil {
                            DatePicker("release date", selection: releaseDate, displayedComponents: .date)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("done") {
                            syncArtists()
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showLyricsEditor) {
                    LyricsEditorView(track: track)
                }
                .onAppear {
                    drafts = track.credits
                        .sorted { $0.position < $1.position }
                        .map { ArtistDraft(name: $0.artist.name, role: $0.role) }
                }
                .padding(.top)
            }
        }
    }
    
    private func syncArtists() {
        for credit in Array(track.credits) {
            modelContext.delete(credit)
        }
        for(position, draft) in drafts.enumerated() {
            let artist = modelContext.findOrCreateArtist(named: draft.name)
            let credit = Credit(artist: artist, role: draft.role, position: position, track: track)
            modelContext.insert(credit)
        }
    }
    
}
