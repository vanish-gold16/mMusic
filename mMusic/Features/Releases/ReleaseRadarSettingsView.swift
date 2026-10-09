import SwiftUI

/// Радар в настройках: за сколькими он следит, когда смотрел и кого
/// не узнал наверняка. Последних удобнее поправить здесь списком, чем
/// обходить страницы артистов по одной.
struct ReleaseRadarSettingsView: View {

    @Environment(ReleaseRadar.self) private var radar

    private var review: [LibraryArtist] {
        radar.library
            .filter { artist in
                guard let entry = radar.artists[artist.key] else { return false }
                return !entry.isMuted && entry.needsReview
            }
            .sorted { $0.weight > $1.weight }
    }

    private var muted: [LibraryArtist] {
        radar.library
            .filter { radar.artists[$0.key]?.isMuted == true }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Watching", value: "\(radar.watchedCount) of \(radar.library.count) artists")

                if let checked = radar.lastCheckAt {
                    LabeledContent("Last check", value: checked.formatted(Date.RelativeFormatStyle(presentation: .named).locale(.interface)))
                }

                Button {
                    Task { await radar.checkNow() }
                } label: {
                    HStack {
                        Text("Check now")
                        if radar.isChecking {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(radar.isChecking)
            } footer: {
                Text("Deezer is checked for every artist each time you open the app (at most every 3 hours) and when iOS wakes it in the background. Features come from Apple Music, which answers slowly, so that pass runs while the app is open or playing.")
            }

            if !review.isEmpty {
                Section {
                    ForEach(review, id: \.key) { artist in
                        NavigationLink {
                            RadarArtistView(name: artist.name)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artist.name)
                                Text(RadarArtistView.status(of: radar.artists[artist.key]?.deezer, on: .deezer))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("needs a look")
                } footer: {
                    Text("Not recognised for sure: no catalog had any of your tracks by them. Pick the right one or tell the radar they're not there.")
                }
            }

            if !muted.isEmpty {
                Section("muted") {
                    ForEach(muted, id: \.key) { artist in
                        NavigationLink(artist.name) {
                            RadarArtistView(name: artist.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("Release radar")
        .navigationBarTitleDisplayMode(.inline)
    }
}
