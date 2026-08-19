import AVFoundation
import Foundation
import MediaPlayer
import Observation
// Ради move(fromOffsets:toOffset:) и remove(atOffsets:) — их объявляет SwiftUI,
// а без них перестановку из List пришлось бы писать руками.
import SwiftUI

@Observable
class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    
    private var meterTimer: Timer?
    private var progressTimer: Timer?

    var queue: [Track] = []
    /// Порядок очереди до перемешивания. Пуст, когда shuffle выключен.
    private var originalQueue: [Track] = []
    var currentIndex: Int = 0
    var currentTrack: Track? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    
    var repeatMode: RepeatMode = .off { didSet { persistModes() } }
    var isShuffled = false { didSet { persistModes() } }

    var level: Double = 0
    private let meterFloor: Double = -50

    private enum Keys {
        static let lastTrack = "lastTrack"
        static let queue = "queue"
        static let repeatMode = "repeatMode"
        static let isShuffled = "isShuffled"
    }

    /// Играли ли мы до звонка. Возобновлять после прерывания нужно только то,
    /// что прервали: иначе музыка сама заиграет там, где её никто не включал.
    private var wasPlayingBeforeInterruption = false
    private var sessionObservers: [NSObjectProtocol] = []
    
    override init() {
        super.init()

        let defaults = UserDefaults.standard
        repeatMode = RepeatMode(rawValue: defaults.string(forKey: Keys.repeatMode) ?? "") ?? .off
        // Очередь сохраняется уже перемешанной, а исходный порядок — нет: после перезапуска
        // shuffle остаётся включённым, но выключение его больше ничего не переставит.
        isShuffled = defaults.bool(forKey: Keys.isShuffled)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
        } catch {
            print("Audio session error: \(error)")
        }
        setupRemoteCommands()
        observeAudioSession()
    }

    deinit {
        sessionObservers.forEach(NotificationCenter.default.removeObserver)
        meterTimer?.invalidate()
        progressTimer?.invalidate()
    }
    
    func play(_ tracks: [Track], startingAt index: Int = 0) {
        guard tracks.indices.contains(index) else { return }
        queue = tracks
        originalQueue = []
        currentIndex = index

        // Пользователь ткнул в конкретный трек — он и должен заиграть,
        // перемешивается только то, что за ним.
        if isShuffled { shuffleQueue() }

        playCurrent()
    }

    /// Кнопка «Shuffle» в альбоме и плейлисте: включает режим и запускает список с начала.
    func playShuffled(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }

        isShuffled = true
        originalQueue = tracks
        queue = tracks.shuffled()
        currentIndex = 0

        playCurrent()
    }
    
    private func playCurrent() {
        guard let track = currentTrack else { return }
        
        let url = AudioFileStore.url(for: track.filename)
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.isMeteringEnabled = true
            player?.play()
            
            persistQueue()
            
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
        isPlaying ? pause() : resume()
    }

    /// Отдельные `pause`/`resume` нужны не только для удобства: система присылает именно
    /// «play» или «pause» (наушники, часы, прерывание), и переключатель на них врёт —
    /// команда «play» во время игры ставила музыку на паузу.
    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
        stopMeterTimer()
        updateNowPlayingInfo()
    }

    func resume() {
        // Плеера нет — значит очередь восстановлена с прошлого запуска и звук ещё не поднимали.
        guard player != nil else {
            if currentTrack != nil { playCurrent() }
            return
        }

        player?.play()
        isPlaying = true
        startProgressTimer()
        startMeterTimer()
        updateNowPlayingInfo()
    }

    /// Полная остановка: очередь остаётся, звук — нет.
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopProgressTimer()
        stopMeterTimer()
        updateNowPlayingInfo()
    }
    
    func playNext() {
        if currentIndex + 1 < queue.count {
            currentIndex += 1
        } else if repeatMode == .all, !queue.isEmpty {
            currentIndex = 0
        } else {
            return
        }
        playCurrent()
    }
    
    func playPrevious() {
        if let time = player?.currentTime, time > 3 {
            seek(to: 0)
            return
        }

        if currentIndex > 0 {
            currentIndex -= 1
        } else if repeatMode == .all, !queue.isEmpty {
            currentIndex = queue.count - 1
        } else {
            seek(to: 0)
            return
        }
        playCurrent()
    }

    /// Прыжок к треку из экрана очереди.
    func jump(to index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        playCurrent()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else {
            finishPlayback()
            return
        }

        switch repeatMode {
        case .one:
            // Повтор одного: тот же файл заново, очередь не двигается.
            playCurrent()
        case .all where !queue.isEmpty:
            currentIndex = (currentIndex + 1) % queue.count
            playCurrent()
        case .all, .off:
            if currentIndex + 1 < queue.count {
                currentIndex += 1
                playCurrent()
            } else {
                finishPlayback()
            }
        }
    }

    /// Очередь кончилась: замираем на последнем кадре, не сбрасывая трек.
    private func finishPlayback() {
        isPlaying = false
        stopProgressTimer()
        stopMeterTimer()
        currentTime = duration
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
            self?.resume()
            return .success
        }
        
        commandsCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandsCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
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
    
    /// «Play next» — треки встают сразу за текущим.
    func enqueueNext(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }

        // Играть нечего — значит это и есть начало воспроизведения.
        guard !queue.isEmpty else {
            play(tracks)
            return
        }

        queue.insert(contentsOf: tracks, at: min(currentIndex + 1, queue.count))
        if !originalQueue.isEmpty { originalQueue.append(contentsOf: tracks) }
        persistQueue()
    }

    /// «Play after» — треки уходят в конец очереди.
    func enqueueLast(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }

        guard !queue.isEmpty else {
            play(tracks)
            return
        }

        queue.append(contentsOf: tracks)
        if !originalQueue.isEmpty { originalQueue.append(contentsOf: tracks) }
        persistQueue()
    }

    func toggleShuffle() {
        isShuffled.toggle()
        isShuffled ? shuffleQueue() : restoreQueueOrder()
        persistQueue()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
    }

    /// Текущий трек продолжает играть и переезжает в начало — мешается то, что впереди.
    private func shuffleQueue() {
        originalQueue = queue

        guard queue.indices.contains(currentIndex) else {
            queue.shuffle()
            return
        }

        let current = queue.remove(at: currentIndex)
        queue.shuffle()
        queue.insert(current, at: 0)
        currentIndex = 0
    }

    /// Возврат к исходному порядку. Текущий трек ищем в нём заново, чтобы музыка не прыгнула.
    private func restoreQueueOrder() {
        guard !originalQueue.isEmpty else { return }

        let current = currentTrack
        queue = originalQueue
        originalQueue = []
        currentIndex = current.flatMap { track in queue.firstIndex { $0.id == track.id } } ?? 0
    }

    /// Перестановка треков на экране очереди.
    func moveInQueue(from source: IndexSet, to destination: Int) {
        let current = currentTrack
        queue.move(fromOffsets: source, toOffset: destination)

        if let current, let index = queue.firstIndex(where: { $0.id == current.id }) {
            currentIndex = index
        }
        persistQueue()
    }

    /// Удаление с экрана очереди — из очереди, но не из библиотеки.
    func removeFromQueue(at offsets: IndexSet) {
        guard !offsets.isEmpty else { return }

        let removedIDs = Set(offsets.compactMap { queue.indices.contains($0) ? queue[$0].id : nil })
        let removingCurrent = offsets.contains(currentIndex)
        // Индекс после удаления съедет, поэтому держимся за сам трек.
        let anchor = removingCurrent ? nil : currentTrack

        if removingCurrent { stop() }

        queue.remove(atOffsets: offsets)
        originalQueue.removeAll { removedIDs.contains($0.id) }

        if let anchor, let index = queue.firstIndex(where: { $0.id == anchor.id }) {
            currentIndex = index
        } else {
            currentIndex = min(currentIndex, max(queue.count - 1, 0))
        }

        persistQueue()
    }

    /// Вызывается перед удалением трека из базы. Без этого он остаётся в очереди
    /// ссылкой на несуществующую строку, и следующий `playNext` падает или играет пустоту.
    func forget(_ track: Track) {
        guard queue.contains(where: { $0.id == track.id }) else { return }

        let removingCurrent = currentTrack?.id == track.id
        // Индекс после удаления съедет, поэтому запоминаем сам трек и ищем его заново.
        let anchor = removingCurrent ? nil : currentTrack

        if removingCurrent { stop() }

        queue.removeAll { $0.id == track.id }
        originalQueue.removeAll { $0.id == track.id }

        if let anchor, let index = queue.firstIndex(where: { $0.id == anchor.id }) {
            currentIndex = index
        } else if removingCurrent {
            // На месте удалённого оказался следующий трек — на него и смотрим.
            currentIndex = min(currentIndex, max(queue.count - 1, 0))
        }

        persistQueue()
    }

    /// Очередь пишется на диск здесь, а зовётся отовсюду, где она меняется.
    private func persistQueue() {
        UserDefaults.standard.set(currentTrack?.filename, forKey: Keys.lastTrack)
        UserDefaults.standard.set(queue.map(\.filename), forKey: Keys.queue)
    }

    private func persistModes() {
        UserDefaults.standard.set(repeatMode.rawValue, forKey: Keys.repeatMode)
        UserDefaults.standard.set(isShuffled, forKey: Keys.isShuffled)
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default

        sessionObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleInterruption(notification)
            }
        )

        sessionObservers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleRouteChange(notification)
            }
        )
    }

    /// Звонок или Siri. Систему не спрашивают — она уже заглушила звук,
    /// наше дело привести `isPlaying` в соответствие и вернуться, когда разрешат.
    private func handleInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying { pause() }
        case .ended:
            guard wasPlayingBeforeInterruption else { return }
            wasPlayingBeforeInterruption = false

            // `.shouldResume` — разрешение системы. Без него возобновлять нельзя:
            // поверх нас может до сих пор говорить навигатор.
            let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            guard AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume) else { return }

            try? AVAudioSession.sharedInstance().setActive(true)
            resume()
        @unknown default:
            break
        }
    }

    /// Наушники вынули. Иначе музыка бодро продолжит играть из динамика на всю комнату.
    private func handleRouteChange(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
              reason == .oldDeviceUnavailable else { return }

        pause()
    }
    
}
