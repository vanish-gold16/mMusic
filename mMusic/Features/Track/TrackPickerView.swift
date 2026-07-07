import SwiftData
import SwiftUI

struct TrackPickerView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @Query private var tracks: [Track]
    
    @State private var selectedTab: TrackPickerTab = .recent
    private var sortedTracks: [Track] {
        switch selectedTab {
        case .recent:
            return tracks.sorted { $0.addedAt > $1.addedAt }
        case .genre:
            return tracks
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
                    LazyVStack(alignment: .leading) {
                        ForEach(sortedTracks) { track in
                            PlaylistTrackPickCell(track: track, playlist: playlist)
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
        }
    }
}
