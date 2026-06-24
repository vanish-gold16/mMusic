import Foundation
import Observation

@Observable
class TrackStore {
    var tracks: [Track] = []
    
    func load() {
        let url = URL.documentsDirectory
        
        do {
            tracks = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "mp3" }
                .map { Track(name: $0.deletingPathExtension().lastPathComponent, artist: "Unknown", filename: $0.lastPathComponent) }
        } catch {
            print("Failed to load tracks: \(error)")
        }
    }
}
