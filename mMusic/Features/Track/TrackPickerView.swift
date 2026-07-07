import SwiftData
import SwiftUI

struct TrackPickerView: View {
    
    @Query private var tracks: [Track]
    
    @State private var selectedTab: TrackPickerTab = .recent
    private var sortedTracks: [Track] {
        switch selectedTab {
        case .recent:
            tracks.sorted { $0.addedAt > $1.addedAt }
        case .genre:
            
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
                ForEach(sortedTracks) { track in
                    PlaylistTrackPickCell(track: track, playlist: playlist)
                }
            }
        }
    }
}
