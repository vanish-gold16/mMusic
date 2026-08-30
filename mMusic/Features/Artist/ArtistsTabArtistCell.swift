import SwiftData
import SwiftUI

struct ArtistsTabArtistCell: View {
    
    @Environment(\.modelContext) private var modelContext

    @State private var showDeleteConfirmation = false
    @State private var showRename = false
    @State private var newName = ""

    var artist: Artist
    
    var body: some View {
        NavigationLink {
            ArtistView(artist: artist)
        } label: {
            HStack {
                ArtistAvatar(artist: artist)
                Text(artist.name)
                Spacer()
            }
        }
        .contextMenu {
            VStack {
                Button {
                    newName = artist.name
                    showRename = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .alert("Rename artist", isPresented: $showRename) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Save") { rename() }
        }
        .confirmationDialog(
            "Remove \"\(artist.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                modelContext.delete(artist)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This artist will be permanently deleted.")
        }
    }

    /// Переименование с оглядкой на дубли: если артист с таким именем уже есть,
    /// вместо второй строки с тем же именем его credits переезжают к существующему.
    private func rename() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != artist.name else { return }

        let descriptor = FetchDescriptor<Artist>(predicate: #Predicate { $0.name == trimmed })
        if let existing = try? modelContext.fetch(descriptor).first,
           existing.persistentModelID != artist.persistentModelID {
            // Копия массива: переназначение credit.artist меняет artist.credits по ходу перебора.
            for credit in Array(artist.credits) {
                credit.artist = existing
            }
            modelContext.delete(artist)
            return
        }

        artist.name = trimmed
    }
}
