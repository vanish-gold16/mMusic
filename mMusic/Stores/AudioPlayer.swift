import AVFoundation
import Foundation
import MediaPlayer
import Observation

@Observable
class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    var currentTrack: Track?
    var isPlaying = false

    override init() {
        super.init()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
        } catch {
            print("Audio session error: \(error)")
        }
        setupRemoteCommands()
    }
    
    func play(_ track: Track) {
        let url = URL.documentsDirectory.appending(path: track.filename)
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            currentTrack = track
            
            UserDefaults.standard.set(track.filename, forKey: "lastTrack")
            
            isPlaying = true
            updateNowPlayingInfo()
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
        updateNowPlayingInfo()
    }
    
    func playNext() {
        
    }
    
    func playPrevious() {
        
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.name,
            MPMediaItemPropertyArtist: track.artistNames.joined(separator: ", "),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPMediaItemPropertyPlaybackDuration: player?.duration ?? 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? 0
        ]
        
        if let artworkData = track.displayArtwork,
           let uiImage = UIImage(data: artworkData) {
            let artwork = MPMediaItemArtwork(boundsSize: uiImage.size) { _ in uiImage }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        
        if let albumName = track.album?.name {
            info[MPMediaItemPropertyAlbumTitle] = albumName
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func setupRemoteCommands() {
        let commandsCenter = MPRemoteCommandCenter.shared()
        
        commandsCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandsCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandsCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        commandsCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
    }
}
