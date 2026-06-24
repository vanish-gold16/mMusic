import Foundation
import AVFoundation
import Observation

@Observable
class AudioPlayer {
    private var player: AVAudioPlayer?
    
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
        print("url: \(url)")
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            print("player created with length: \(player?.duration ?? 0) sec")
            player?.play()
            print("play() called")
        } catch {
            print(error)
        }
    }
}
