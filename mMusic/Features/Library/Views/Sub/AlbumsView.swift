import SwiftData
import SwiftUI

struct AlbumsView: View {

    @Query(sort: \Album.addedAt, order: .reverse) private var albums: [Album]

    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateAdded

    private let columns = [GridItem(.flexible(), alignment: .top),
                           GridItem(.flexible(), alignment: .top)]

    private enum SortOption: String, CaseIterable, Identifiable {
        case dateAdded = "Date Added"
        case name = "Name"
        case release = "Release Date"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .dateAdded: return "clock"
            case .name: return "textformat"
            case .release: return "calendar"
            }
        }
    }

    private var displayedAlbums: [Album] {
        let filtered: [Album]
        if searchText.isEmpty {
            filtered = albums
        } else {
            filtered = albums.filter { album in
                album.name.localizedCaseInsensitiveContains(searchText)
                || album.artistNames.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        switch sortOption {
        case .dateAdded:
            return filtered.sorted { $0.addedAt > $1.addedAt }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .release:
            return filtered.sorted {
                ($0.release ?? .distantPast) > ($1.release ?? .distantPast)
            }
        }
    }

    var body: some View {
        ScrollView {
            searchBar
                .padding(.horizontal)
                .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(displayedAlbums) { album in
                    AlbumCell(album: album)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .navigationTitle("Albums")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search albums", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOption) {
                ForEach(SortOption.allCases) { option in
                    Label(option.rawValue, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
}
