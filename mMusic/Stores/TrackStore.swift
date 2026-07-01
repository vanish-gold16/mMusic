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
                .map {
                    $0.parseMusic()
                }
            print("Found \(tracks.count) tracks")
        } catch {
            print("Failed to load tracks: \(error)")
        }
    }
    
    func delete(_ track: Track) {
        let url = URL.documentsDirectory.appending(path: track.filename)
        
        do {
            try FileManager.default.removeItem(at: url)
            tracks.removeAll { $0.id == track.id }
        } catch {
            print("\(error)")
        }
    }
}

extension URL {
    func parseMusic() -> Track {
        let base = deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")

        if let range = base.range(of: " — ")        // длинное тире
                    ?? base.range(of: " – ")         // среднее тире (en-dash) ← добавили
                    ?? base.range(of: " - ") {
            let artist = String(base[..<range.lowerBound])
            let title = String(base[range.upperBound...])
            return Track(name: title, artist: artist, genre: .other, filename: lastPathComponent)
        } else {
            return Track(name: base, artist: "Unknown", genre: .other, filename: lastPathComponent)
        }
    }
}
