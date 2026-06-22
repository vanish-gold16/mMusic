import SwiftUI

struct SearchTab: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        NavigationStack (path: $path) {
            SearchView()
        }
    }
}
