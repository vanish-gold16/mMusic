import SwiftData
import SwiftUI
import Foundation

struct ArtistsEditor: View {
    
    @Binding var artists: [ArtistDraft]

    /// Артисты альбома, показываются перед редактируемыми капсулами в общем потоке (только для чтения).
    var readOnlyArtists: [String] = []

    @Query(sort: \Artist.name) private var allArtists: [Artist]
    @State private var newArtistName = ""
    @State private var showAddArtist = false
    @State private var draggingArtist: ArtistDraft?
    @State private var dragOffset: CGSize = .zero
    @State private var cellFrames: [UUID: CGRect] = [:]
    
    private var suggestions: [Artist] {
        if newArtistName.isEmpty {
            return []
        } else {
            return allArtists.filter { $0.name.localizedCaseInsensitiveContains(newArtistName) }
        }
    }
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(readOnlyArtists, id: \.self) { name in
                TrackArtistCell(name: name, showDelete: false, showRole: false, editable: false)
            }

            ForEach(artists) { draft in
                artistCell(for: draft)
            }
            
            Button {
                newArtistName = ""
                showAddArtist = true
            } label: {
                Image(systemName: "plus")
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.2), in: Circle())
            }
            .buttonStyle(.borderless)
            .fixedSize()
            .popover(isPresented: $showAddArtist) {
                VStack(spacing: 16) {
                    TextField("artist name", text: $newArtistName)
                        .padding(10)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                    if !suggestions.isEmpty {
                        ScrollView {
                            ForEach(suggestions) { artist in
                                TrackArtistCell(name: artist.name, showDelete: false, showRole: false, editable: true, onTap: {
                                    artists.append(ArtistDraft(name: artist.name))
                                    showAddArtist = false
                                })
                            }
                        }
                    }
                    Button("add") {
                        artists.append(ArtistDraft(name: newArtistName))
                        showAddArtist = false
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(newArtistName.isEmpty)
                }
                .padding()
                .frame(width: 280, height: 220)
                .presentationCompactAdaptation(.popover)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .coordinateSpace(name: "artistsFlow")
        .onPreferenceChange(CellFramePreferenceKey.self) {
            cellFrames = $0
        }
    }
    
    @ViewBuilder
    private func artistCell(for draft: ArtistDraft) -> some View {
        let isDragging = draggingArtist?.id == draft.id
        TrackArtistCell(name: draft.name, role: draft.role, showDelete: true, showRole: true, editable: true, onTap: {
            toggleRole(for: draft)
        }, onRemove: {
            artists.removeAll { $0.id == draft.id }
        })
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: CellFramePreferenceKey.self,
                    value: [draft.id: geo.frame(in: .named("artistsFlow"))]
                )
            }
        )
        .opacity(isDragging ? 0.6 : 1)
        .offset(isDragging ? dragOffset : .zero)
        .zIndex(isDragging ? 1 : 0)
        .gesture(dragGesture(for: draft))
    }
    
    private func dragGesture(for draft: ArtistDraft) -> some Gesture {
        DragGesture(coordinateSpace: .named("artistsFlow"))
            .onChanged { value in
                if draggingArtist?.id != draft.id {
                    draggingArtist = draft
                }
                dragOffset = value.translation
            }
            .onEnded { value in
                if let targetID = cellFrames.first(where: { $0.value.contains(value.location) })?.key,
                   targetID != draft.id,
                   let from = artists.firstIndex(where: { $0.id == draft.id }),
                   let to = artists.firstIndex(where: { $0.id == targetID }) {
                    withAnimation {
                        artists.move(
                            fromOffsets: IndexSet(integer: from),
                            toOffset: to > from ? to + 1 : to
                        )
                    }
                }
                draggingArtist = nil
                dragOffset = .zero
            }
    }
    
    private func toggleRole(for draft: ArtistDraft) {
        guard let index = artists.firstIndex(where: { $0.id == draft.id }) else { return }
        artists[index].role = artists[index].role == .main ? .featured : .main
    }
    
}

/// Сохраняет фреймы капсул артистов в общей системе координат для попадания при перетаскивании.
struct CellFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Раскладывает капсулы в строку, перенося на следующую, когда не влезают по ширине.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
        }
        return CGSize(width: totalWidth, height: currentY + rowHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), anchor: .topLeading, proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
