import SwiftData
import SwiftUI

struct ArtistsView: View {
    
    @Query private var artists: [Artist]
    
    var body: some View {
        ScrollView {
            ForEach(artists) {
                
            }
        }
    }
}
