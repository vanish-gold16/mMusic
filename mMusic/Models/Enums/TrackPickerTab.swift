enum TrackPickerTab: String, CaseIterable, Identifiable {
    case recent = "Recently added"
    case genre = "Genre"

    var id: String { rawValue }
}
