import SwiftData
import SwiftUI

struct TrackPickerView: View {
    
    @Query private var tracks: [Track]
    
    var body: some View {
        HStack {
            ForEach(tracks) { track in
                PlaylistTrackCell(track: track)
            }
        }
    }
}
