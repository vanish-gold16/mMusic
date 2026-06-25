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
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    func play(_ track: Track) {
        print("Play called for \(track.name)")
        let url = URL.documentsDirectory.appending(path: track.filename)
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            currentTrack = track
            isPlaying = true
        } catch {
            print(error)
        }
    }
    
    func togglePlayPause() {
        print("toggle нажат! isPlaying было \(isPlaying)")
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
    }
}
