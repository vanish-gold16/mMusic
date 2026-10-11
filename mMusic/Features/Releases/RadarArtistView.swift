import SwiftUI

/// Радар одного артиста: присылать ли о нём и кем он оказался в каждом
/// каталоге. Здесь же это и правится — если радар перепутал его с тёзкой
/// или не нашёл вовсе.
struct RadarArtistView: View {

    @Environment(ReleaseRadar.self) private var radar

    let name: String

    private var entry: RadarArtist? {
        radar.artist(named: name)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Mute releases", isOn: mutedBinding(radar, name))
            } footer: {
                Text(entry?.isMuted == true
                     ? "Nothing by \(name) reaches you: no notifications, nothing on Home or in Drops."
                     : "New albums, EPs, singles and features by \(name) land on Home and in Drops, and a notification comes with them.")
            }

            matchSection(.deezer, match: entry?.deezer, footer: "Albums, EPs and singles where \(name) is the main artist.")
            matchSection(.apple, match: entry?.apple, footer: "Features: other artists' releases \(name) is on.")
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func matchSection(_ source: RadarRelease.Source, match: RadarMatch?, footer: String) -> some View {
        Section {
            HStack(spacing: 12) {
                RemoteCover(url: match?.picture, pixels: 120, isCircle: true)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(match?.name ?? "—")
                    Text(Self.status(of: match, on: source))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Узнан только по имени — одной кнопкой подтвердить, что это он.
            if match?.status == .probable, let match, let id = match.id {
                Button("It's them") {
                    radar.pick(
                        RadarLogic.Candidate(id: id, name: match.name ?? name, picture: match.picture, fans: 0, titleKeys: []),
                        on: source,
                        for: name
                    )
                }
            }

            NavigationLink("Choose another") {
                RadarCandidatesView(source: source, name: name)
            }
        } header: {
            Text(source.title)
        } footer: {
            Text(footer)
        }
    }

    static func status(of match: RadarMatch?, on source: RadarRelease.Source) -> String {
        switch match?.status {
        case .confirmed: "Matched by your tracks"
        case .probable: "Matched by name only — make sure it's them"
        case .picked: "Picked by you"
        case .missing: "Not found — the radar tries again in a week"
        case .rejected: "Not on \(source.title)"
        case nil: "Not checked yet"
        }
    }
}

/// Выбор артиста в каталоге руками: поиск по имени, слушатели или жанр
/// под каждым — чтобы отличить его от тёзки.
struct RadarCandidatesView: View {

    @Environment(ReleaseRadar.self) private var radar
    @Environment(\.dismiss) private var dismiss

    let source: RadarRelease.Source
    let name: String

    @State private var query: String
    @State private var results: [RadarLogic.Candidate] = []
    @State private var isSearching = false

    init(source: RadarRelease.Source, name: String) {
        self.source = source
        self.name = name
        _query = State(initialValue: name)
    }

    var body: some View {
        List {
            Section {
                ForEach(results, id: \.id) { candidate in
                    Button {
                        radar.pick(candidate, on: source, for: name)
                        dismiss()
                    } label: {
                        row(candidate)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                if isSearching {
                    ProgressView()
                } else if results.isEmpty {
                    Text("Nobody by that name on \(source.title).")
                }
            }

            Section {
                Button("Not on \(source.title)", role: .destructive) {
                    radar.reject(on: source, for: name)
                    dismiss()
                }
            } footer: {
                Text("The radar stops looking for \(name) there.")
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(source.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: query) {
            // Не на каждую букву: ждём, пока перестанут печатать.
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    private func row(_ candidate: RadarLogic.Candidate) -> some View {
        HStack(spacing: 12) {
            RemoteCover(url: candidate.picture, pixels: 120, isCircle: true)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                if !candidate.detail.isEmpty {
                    Text(candidate.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if radar.artist(named: name).flatMap({ source == .deezer ? $0.deezer : $0.apple })?.id == candidate.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            results = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        switch source {
        case .deezer:
            let found = (try? await DeezerClient.searchArtists(named: text)) ?? []
            results = found.map { artist in
                RadarLogic.Candidate(
                    id: artist.id, name: artist.name, picture: artist.picture,
                    fans: artist.fans ?? 0, titleKeys: [],
                    detail: "\((artist.fans ?? 0).formatted(.number.notation(.compactName))) fans"
                )
            }
        case .apple:
            let found = (try? await AppleMusicClient.searchArtists(named: text)) ?? []
            results = found.map { artist in
                RadarLogic.Candidate(
                    id: artist.artistId, name: artist.artistName, picture: nil,
                    fans: 0, titleKeys: [], detail: artist.primaryGenreName ?? ""
                )
            }
        }
    }
}

/// Пункты радара в меню артиста: заглушить его одним касанием — или открыть
/// радар целиком и посмотреть, кем он считается в каталогах. Сам лист радара
/// открывает владелец меню (`radarArtistSheet`): меню закрывается раньше,
/// чем лист успевает открыться.
struct RadarArtistMenuItems: View {

    @Environment(ReleaseRadar.self) private var radar

    let name: String
    let onOpen: () -> Void

    var body: some View {
        Toggle(isOn: mutedBinding(radar, name)) {
            Label("Mute releases", systemImage: "bell.slash")
        }

        Button(action: onOpen) {
            // Второй текст в пункте меню — его подпись мелким шрифтом.
            Label("Release radar", systemImage: "dot.radiowaves.left.and.right")
            Text(status)
        }
    }

    /// Подпись под пунктом: следит ли радар и уверен ли, что это он.
    private var status: String {
        guard let entry = radar.artist(named: name) else { return "Not checked yet" }
        if entry.isMuted { return "Muted" }
        if entry.deezer?.isWatched == true || entry.apple?.isWatched == true { return "Watching" }
        return entry.needsReview ? "Needs a look" : "Not found"
    }
}

extension View {

    /// Лист радара одного артиста — его открывает пункт «Release radar».
    func radarArtistSheet(name: String, isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            NavigationStack {
                RadarArtistView(name: name)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            SheetActionButton(.done) { isPresented.wrappedValue = false }
                        }
                    }
            }
        }
    }
}

/// «Заглушить» в меню и в листе радара — один и тот же переключатель.
@MainActor
private func mutedBinding(_ radar: ReleaseRadar, _ name: String) -> Binding<Bool> {
    Binding(
        get: { radar.artist(named: name)?.isMuted ?? false },
        set: { radar.setMuted($0, artist: name) }
    )
}
