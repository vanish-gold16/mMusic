import SwiftData
import SwiftUI

struct TrackPickerView: View {
    
    @Query private var tracks: [Track]
    
    var playlist: Playlist
    
    var body: some View {
        VStack {
            ForEach(tracks) { track in
                PlaylistTrackPickCell(track: track, playlist: playlist)
            }
        }
    }
}
