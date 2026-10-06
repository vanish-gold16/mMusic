enum TrackPickerTab: String, CaseIterable, Identifiable {
    case recent = "Recently added"
    case genre = "By genre"

    var id: String { rawValue }
}
