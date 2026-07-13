import SwiftUI

struct HomeView: View {
    
    @State private var showSettings = false
    
    var body: some View {
        Text("Home")
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        NavigationLink(destination: PlaylistsView()) {
                            Label("Playlists", systemImage: "music.note.list")
                        }
                        NavigationLink(destination: AlbumsView()) {
                            Label("ALbums", systemImage: "square.stack")
                        }
                        NavigationLink(destination: ArtistsView()) {
                            Label("Artists", systemImage: "music.note")
                        }
                     } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
    }
}
