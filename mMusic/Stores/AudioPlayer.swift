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
            
            if let filename = UserDefaults.standard.string(forKey: "lastTrack") {
                let url = URL.documentsDirectory.appending(path: filename)
                currentTrack = url.parseMusic()
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
            
            UserDefaults.standard.set(track.filename, forKey: "lastTrack")
            
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
