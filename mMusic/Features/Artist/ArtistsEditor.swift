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
            return allArtists
                .filter { $0.name.localizedCaseInsensitiveContains(newArtistName) }
                .filter { !isAlbumArtist($0.name) }
        }
    }

    /// Артисты трека без тех, кто уже указан у альбома: они наследуются и показываются read-only.
    private var editableArtists: [ArtistDraft] {
        artists.filter { !isAlbumArtist($0.name) }
    }

    private func isAlbumArtist(_ name: String) -> Bool {
        readOnlyArtists.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Убирает из списка трека артистов, которые уже есть у альбома.
    private func dropInheritedArtists() {
        artists.removeAll { isAlbumArtist($0.name) }
    }
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(readOnlyArtists, id: \.self) { name in
                TrackArtistCell(name: name, showDelete: false, showRole: false, editable: false)
            }

            ForEach(editableArtists) { draft in
                artistCell(for: draft)
            }
            
            Button {
                newArtistName = ""
                showAddArtist = true
            } label: {
                // Того же роста, что капсулы артистов, — иначе строка прыгает.
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassEffect(in: Capsule())
            }
            .buttonStyle(.borderless)
            .fixedSize()
            .popover(isPresented: $showAddArtist) {
                VStack(spacing: 16) {
                    TextField("artist name", text: $newArtistName)
                        .padding(10)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                    if isAlbumArtist(newArtistName) {
                        Text("already an album artist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                    .disabled(newArtistName.isEmpty || isAlbumArtist(newArtistName))
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
        .onAppear {
            dropInheritedArtists()
        }
        .onChange(of: readOnlyArtists) {
            dropInheritedArtists()
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
        arrange(subviews, width: proposal.width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        // Переносим тем же расчётом и по той же ширине, что при замере, а не по bounds.
        // bounds — это замеренная ширина строки впритык, а правый край здесь
        // складывался в другом порядке, и дробные ширины («Adaro» + «LP»)
        // расходились в последнем знаке. Последняя капсула «не влезала»,
        // уезжала на новую строку — ниже посчитанной высоты, поверх соседей.
        let frames = arrange(subviews, width: proposal.width).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    /// Рамки капсул относительно левого верхнего угла и общий размер потока.
    private func arrange(_ subviews: Subviews, width: CGFloat?) -> (frames: [CGRect], size: CGSize) {
        let maxWidth = width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            // Капсула шире всей строки — например, артист, в имя которого при
            // импорте попало название файла, — ставится во всю строку и сама
            // обрезает подпись. Иначе поток становился шире экрана и растягивал
            // за собой всю форму вбок.
            if size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                size.width = min(size.width, maxWidth)
            }
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
        }
        return (frames, CGSize(width: totalWidth, height: currentY + rowHeight))
    }
}
