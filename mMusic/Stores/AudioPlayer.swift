import AVFoundation
import Foundation
import MediaPlayer
import Observation

@Observable
class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    
    private var meterTimer: Timer?
    private var progressTimer: Timer?

    var queue: [Track] = []
    var currentIndex: Int = 0
    var currentTrack: Track? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    
    var level: Double = 0
    private let meterFloor: Double = -50
    
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
    
    func play(_ tracks: [Track], startingAt index: Int = 0) {
        guard tracks.indices.contains(index) else { return }
        queue = tracks
        currentIndex = index
        playCurrent()
    }
    
    private func playCurrent() {
        guard let track = currentTrack else { return }
        
        let url = URL.documentsDirectory.appending(path: track.filename)
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.isMeteringEnabled = true
            player?.play()
            
            UserDefaults.standard.set(track.filename, forKey: "lastTrack")
            UserDefaults.standard.set(queue.map(\.filename), forKey: "queue")
            
            isPlaying = true
            duration = player?.duration ?? 0
            currentTime = 0
            startProgressTimer()
            startMeterTimer()
            updateNowPlayingInfo()
        } catch {
            print(error)
        }
    }

    func togglePlayPause() {
        if isPlaying {
            player?.pause()
            isPlaying = false
            stopProgressTimer()
            stopMeterTimer()
        } else {
            if (player == nil && currentTrack != nil) {
                playCurrent()
            } else {
                player?.play()
                isPlaying = true
                startProgressTimer()
                startMeterTimer()
            }
        }
        updateNowPlayingInfo()
    }
    
    func playNext() {
        guard currentIndex + 1 < queue.count else { return }
        currentIndex += 1
        playCurrent()
    }
    
    func playPrevious() {
        if let time = player?.currentTime, time > 3 {
            seek(to: 0)
            return
        }
        guard currentIndex > 0 else { seek(to: 0); return }
        currentIndex -= 1
        playCurrent()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag && currentIndex + 1 < queue.count {
            currentIndex += 1
            playCurrent()
        } else {
            isPlaying = false
            stopProgressTimer()
            stopMeterTimer()
            currentTime = duration
        }
        updateNowPlayingInfo()
    }

    private func startProgressTimer() {
        stopProgressTimer()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func startMeterTimer() {
        stopMeterTimer()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            player.updateMeters()

            let db = Double(player.averagePower(forChannel: 0))
            let normalized = (db - self.meterFloor) / (0 - self.meterFloor)
            self.level = min(max(normalized, 0), 1)
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
        level = 0
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
        
        commandsCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }
    
    func seek(to time: TimeInterval) {
        let clamped = min(max(0, time), duration)
        player?.currentTime = clamped
        currentTime = clamped
        updateNowPlayingInfo()
    }

    func restore(_ tracks: [Track], current filename: String) {
        queue = tracks
        currentIndex = tracks.firstIndex { $0.filename == filename } ?? 0
    }
    
    func shorten(to time: TimeInterval) {
        let clamped = min(max(0, time), duration)
        level = clamped
    }
    
}
