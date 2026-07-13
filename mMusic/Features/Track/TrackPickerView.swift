import SwiftData
import SwiftUI

struct TrackPickerView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @Query private var tracks: [Track]
    
    @State private var selectedTab: TrackPickerTab = .recent
    @State private var searchText = ""
    
    private var recentTracks: [Track] {
        filteredTracks.sorted { $0.addedAt > $1.addedAt }
    }
    private var genreGroups: [(genre: Genre, tracks: [Track])] {
        Dictionary(grouping: filteredTracks, by: { $0.genre })
            .map { (genre: $0.key, tracks: $0.value) }
            .sorted { $0.genre.rawValue < $1.genre.rawValue }
    }
    private var filteredTracks: [Track] {
        guard !searchText.isEmpty else { return tracks }
        return tracks.filter { track in
            track.name.localizedCaseInsensitiveContains(searchText)
            || track.artists.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var playlist: Playlist
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Section", selection: $selectedTab) {
                    ForEach(TrackPickerTab.allCases) {tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        switch selectedTab {
                        case .recent:
                            ForEach(recentTracks) { track in
                                PlaylistTrackPickCell(track: track, playlist: playlist)
                            }
                        case .genre:
                            ForEach(genreGroups, id: \.genre) { group in
                                Text(group.genre.rawValue)
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                ForEach(group.tracks) { track in
                                    PlaylistTrackPickCell(track: track, playlist: playlist)
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText)
        }
    }
}
