import SwiftData
import SwiftUI

struct CreateAlbumView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var tracks: [Track] = []
    @State private var trackDrafts: [TrackDraft] = []
    @State private var artworkData: Data?
    @State private var artists: [ArtistDraft] = []
    @State private var release: Date?
    @State private var pickedFile: PickedFile? = nil
    
    @State private var showImagePicker = false
    @State private var showTrackPicker = false
    @State private var isImporting = false
    
    private var hasRelease: Binding<Bool> {
        Binding (
            get: { release != nil },
            set: { release = $0 ? .now : nil }
        )
    }
    private var releaseDate: Binding<Date> {
        Binding(
            get: { release ?? .now },
            set: { release = $0 }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Group {
                            if let artworkData, let uiImage = UIImage(data: artworkData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                    }
                            }
                        }
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("Pick an image", systemImage: "photo")
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.glassProminent)
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(imageData: $artworkData)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
                Section("album name") {
                    TextField("", text: $name)
                }
                Section("artists") {
                    ArtistsEditor(artists: $artists)
                }
                Section("release") {
                    Toggle("has release date", isOn: hasRelease)
                    if release != nil {
                        DatePicker("release date", selection: releaseDate, displayedComponents: .date)
                    }
                }
                VStack {
                    HStack(spacing: 16) {
                        Button {
                            
                        } label: {
                            VStack {
                                Text("Upload music")
                                Image(systemName: "square.and.arrow.down")
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 15))
                        .tint(.blue)
                        Button {
                            
                        } label: {
                            VStack {
                                Text("From YouTube")
                                Image(systemName: "video")
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 15))
                        .tint(.red)
                    }
                    Button {
                        
                    } label: {
                        VStack {
                            Text("Soundloud")
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 15))
                .padding(.top)
                .tint(.orange)
                if !tracks.isEmpty {
                    ForEach(tracks) { track in
                        AlbumTrackCell(track: track)
                    }
                }
                Section {
                    Button {
                        showTrackPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add Music")
                                .tint(.primary)
                        }
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.glassProminent)
                    .sheet(isPresented: $showTrackPicker) {
                        AlbumTrackPickerView(album: [], addedTracks: $trackDrafts)
                    }
                }
            }
            .navigationTitle("New album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        dismiss()
                    }
                }
            }
        }
    }
}
