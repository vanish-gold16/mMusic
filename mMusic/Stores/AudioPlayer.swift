import Foundation
import AVFoundation
import Observation

@Observable
class AudioPlayer {
    private var player: AVAudioPlayer?
    
    var currentTrack: Track?
    var isPlaying = false
    
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            do {
                if let data = UserDefaults.standard.data(forKey: "lastTrack") {
                    let decoder = JSONDecoder()
                    let track = try decoder.decode(Track.self, from: data)
                    currentTrack = track
                }
            } catch {
                print("Error restoring the track in init() : \(error)")
            }
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    func play(_ track: Track) {
        let url = URL.documentsDirectory.appending(path: track.filename)
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            currentTrack = track
            
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(track)
                UserDefaults.standard.set(data, forKey: "lastTrack")
            } catch {
                print("Error saving the last track: \(error)")
            }
            
            isPlaying = true
        } catch {
            print(error)
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if (player == nil && currentTrack != nil) {
                play(currentTrack!)
            } else {
                player?.play()
                isPlaying = true
            }
        }
    }
}
