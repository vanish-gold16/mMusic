import SwiftData
import SwiftUI

/// Правка трека. Наверху — пластинка его альбома, и кольцо этого трека горит
/// на ней акцентом: видно, какой он там по счёту и сколько места занимает.
/// Дальше — как в форме нового трека: имя крупно в шапке, авторы, жанр, текст.
///
/// Поля пишутся в трек сразу, кроме авторов: те собираются в черновике
/// и переезжают в базу по «DONE».
struct EditTrackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer
    
    @Bindable var track: Track
    
    @State private var showLyricsEditor = false
    
    @State private var drafts: [ArtistDraft] = []

    /// Обложка в превью, уменьшенная в фоне, и цвета, которыми светится форма.
    @State private var cover: UIImage?
    @State private var palette: CoverPalette?

    private var accent: Color {
        palette?.accent ?? audioPlayer.accent
    }

    /// Пока трек в альбоме с обложкой, обложка у него альбомная — своя всё равно
    /// не покажется, и предлагать её выбрать было бы обманом. Выбранная раньше
    /// никуда не делась: она вернётся, если трек выйдет из альбома или у альбома
    /// не станет обложки.
    private var coverBelongsToAlbum: Bool {
        track.album?.artwork != nil
    }

    /// Дата живёт на альбоме: у сингла это дата самого трека, у альбома — общая.
    private var release: Binding<Date?> {
        Binding(
            get: { track.album?.release },
            set: { track.album?.release = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    RecordFormSection("Artists") {
                        VStack(alignment: .leading, spacing: 10) {
                            ArtistsEditor(
                                artists: $drafts,
                                readOnlyArtists: track.album?.artists.map(\.name) ?? []
                            )
                            RecordHint("Tap a name to mark a guest")
                        }
                        .padding(.horizontal)
                    }

                    RecordFormSection("Genre") {
                        GenreMenu(genre: $track.genre)
                            .padding(.horizontal)
                    }

                    RecordFormSection("Text") {
                        lyricsCard
                            .padding(.horizontal)
                    }

                    if track.album != nil {
                        RecordFormSection("Released", detail: track.album?.type == .single ? "" : "Whole album") {
                            ReleaseDateField(date: release)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .containerBackground(for: .navigation) {
                CoverAura(palette: palette, breathes: false)
            }
            // Всё в цвет обложки. Строго до `.toolbar` и листов: редактор текста
            // остаётся в цвете приложения.
            .tint(accent)
            .task(id: track.displayArtwork?.count) {
                let (image, colors) = await UIImage.coverAndPalette(from: track.displayArtwork)
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.3)) {
                    cover = image
                    palette = colors
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetActionButton(.done) {
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
        }
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            if coverBelongsToAlbum {
                sleeve
            } else {
                CoverEditMenu(artworkData: $track.artwork) { sleeve }
            }

            VStack(alignment: .leading, spacing: 6) {
                RecordTitleField(placeholder: "Track name", text: $track.name)
                RecordPassport(parts: passport)

                if coverBelongsToAlbum, let album = track.album {
                    RecordHint("Cover comes from \"\(album.name)\"")
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    /// Пластинка альбома с горящим кольцом этого трека. Трек без альбома —
    /// маленький диск из одного кольца, как у сингла.
    private var sleeve: some View {
        let album = track.album
        let discs = album.map { $0.discs.map { $0.map(\.duration) } } ?? [[track.duration]]
        let position = album?.position(of: track) ?? DiscPosition(disc: 0, track: 0)

        return AlbumSleeve(
            cover: cover,
            type: album?.type ?? .single,
            discs: discs,
            outDisc: position.disc,
            playing: position,
            isPlaying: false,
            accent: accent
        )
        .frame(width: 250)
    }

    /// «LP  ·  TRACK 3  ·  3:41» — у двойного ещё и пластинка: «2×LP  ·  DISC 2  ·  TRACK 3».
    private var passport: [String] {
        var parts: [String] = []

        if let album = track.album {
            parts.append(album.formatLabel)

            if let position = album.position(of: track) {
                if album.discCount > 1 { parts.append("disc \(position.disc + 1)") }
                parts.append("track \(position.track + 1)")
            }
        }

        if track.duration > 0 {
            parts.append(Duration.seconds(track.duration).formatted(.time(pattern: .minuteSecond)))
        }

        return parts
    }

    /// Текст песни: первые строки в стеклянной карточке — по ним сразу видно,
    /// тот ли это текст. Нет текста — пунктирный слот.
    @ViewBuilder
    private var lyricsCard: some View {
        if let lyrics = track.lyrics, track.hasLyrics {
            Button {
                showLyricsEditor = true
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text(lyrics.split(separator: "\n").prefix(3).joined(separator: "\n"))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .glassEffect(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit text")
        } else {
            DashedSlot(title: "Add text", systemImage: "quote.bubble", cornerRadius: 26) {
                showLyricsEditor = true
            }
            .frame(maxWidth: 200)
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
