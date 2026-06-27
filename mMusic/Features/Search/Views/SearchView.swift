import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""
    
    var body: some View {
        Text("Search")
            .navigationTitle("Search")
            .searchable(text: $searchText)
    }
}
