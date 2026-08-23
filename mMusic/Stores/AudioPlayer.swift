import AVFoundation
import Foundation
import MediaPlayer
import Observation
import SwiftData
// Ради move(fromOffsets:toOffset:) и remove(atOffsets:) — их объявляет SwiftUI,
// а без них перестановку из List пришлось бы писать руками.
import SwiftUI

@Observable
class AudioPlayer: NSObject {
    /// Звук отдан отдельному типу: там граф из скорости, тона и эха, который
    /// можно крутить на ходу. Здесь остаётся очередь, история и связь с системой.
    private let engine = PlaybackEngine()
    
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

    /// Цвета играющей обложки: ими красится фон плеера и tint всего приложения.
    /// Пока ничего не играет, стоит запасная палитра.
    private(set) var palette: CoverPalette = .fallback

    /// Короткие имена для самых частых мест — читаются как раньше.
    var accent: Color { palette.accent }
    var secondaryAccent: Color { palette.secondary }

    var level: Double = 0
    private let meterFloor: Double = -50

    /// Насколько громко звучит трек прямо сейчас — от 0 (тихое место) до 1 (удар).
    /// На этом числе «дышит» фон плеера.
    ///
    /// Считается здесь, а не на экране: фон показывает не только плеер, но и то,
    /// что открыто из него, и дышать они должны в такт.
    private(set) var punch: Double = 0

    /// Сглаженная громкость: тянется за `level`, но лениво, иначе фон мигал бы
    /// на каждой ноте.
    private var glow: Double = 0
    /// Ползучие границы громкости этого трека — подстраиваются сами, чтобы фон
    /// одинаково хорошо дышал и на тихой записи, и на громкой.
    private var quiet: Double = 0
    private var loud: Double = 1
    private var isRangeCalibrated = false

    /// Хранилище настроек внедряется: с жёстким `UserDefaults.standard` тесты писали
    /// режимы повтора прямо в настройки приложения, а следующий прогон их читал.
    private let defaults: UserDefaults

    private enum Keys {
        static let lastTrack = "lastTrack"
        static let queue = "queue"
        static let repeatMode = "repeatMode"
        static let isShuffled = "isShuffled"
    }

    /// Играли ли мы до звонка. Возобновлять после прерывания нужно только то,
    /// что прервали: иначе музыка сама заиграет там, где её никто не включал.
    private var wasPlayingBeforeInterruption = false
    /// Засчитан ли текущий трек. Сбрасывается на каждом запуске трека,
    /// поэтому повтор одного и того же честно считается заново.
    private var didCountCurrentPlay = false

    /// Контекст для записи истории. Присваивается из `RootView`: плеер живёт
    /// в `@State` и своего контекста не получает.
    var modelContext: ModelContext?
    /// Событие текущего прослушивания. Создаётся, когда трек засчитан, и до конца
    /// прослушивания копит секунды — так в истории оказывается реальное время,
    /// а не порог засчитывания.
    private var currentEvent: PlayEvent?

    /// Когда таймер сна погасит музыку. nil — таймера нет.
    var sleepEndsAt: Date?
    /// Остановиться, доиграв текущий трек: обрывать песню на середине — не то,
    /// чего ждут от таймера сна.
    var stopsAfterCurrentTrack = false
    private var sleepTask: Task<Void, Never>?
    private var sessionObservers: [NSObjectProtocol] = []
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()

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
        engine.onFinish = { [weak self] in
            self?.handleTrackFinished()
        }

        setupRemoteCommands()
        observeAudioSession()
    }

    deinit {
        sleepTask?.cancel()
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

        // До попытки открыть файл: обложка есть и у трека, который не удалось прочитать,
        // а интерфейс всё равно перекрашивается под него.
        refreshPalette()

        // У нового трека своя громкость — коридор ищем заново.
        isRangeCalibrated = false

        do {
            try engine.load(url)
            // Ручки этого трека — до первого звука, иначе первые доли секунды
            // играли бы с настройками предыдущего.
            engine.apply(currentRemix)
            engine.play()

            track.lastPlayedAt = .now
            didCountCurrentPlay = false
            currentEvent = nil
            persistQueue()
            
            isPlaying = true
            duration = engine.duration
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
        engine.pause()
        isPlaying = false
        stopProgressTimer()
        stopMeterTimer()
        updateNowPlayingInfo()
    }

    func resume() {
        // Файл не открыт — значит очередь восстановлена с прошлого запуска
        // и звук ещё не поднимали.
        guard engine.hasTrack else {
            if currentTrack != nil { playCurrent() }
            return
        }

        engine.apply(currentRemix)
        engine.play()
        isPlaying = true
        startProgressTimer()
        startMeterTimer()
        updateNowPlayingInfo()
    }

    /// Полная остановка: очередь остаётся, звук — нет.
    func stop() {
        engine.stop()
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
        if engine.hasTrack, engine.currentTime > 3 {
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

    /// Таймер сна на заданное число минут. Повторный вызов заменяет предыдущий.
    func startSleepTimer(minutes: Int) {
        cancelSleepTimer()

        let seconds = minutes * 60
        sleepEndsAt = .now.addingTimeInterval(TimeInterval(seconds))

        sleepTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }

            pause()
            sleepEndsAt = nil
        }
    }

    func stopAfterCurrentTrack() {
        cancelSleepTimer()
        stopsAfterCurrentTrack = true
    }

    func cancelSleepTimer() {
        sleepTask?.cancel()
        sleepTask = nil
        sleepEndsAt = nil
        stopsAfterCurrentTrack = false
    }

    var hasSleepTimer: Bool {
        sleepEndsAt != nil || stopsAfterCurrentTrack
    }

    /// Общая скорость из настроек — значение по умолчанию для треков, которые
    /// никто не крутил. У трека со своим ремиксом ручки главнее, поэтому его
    /// она не трогает.
    func applyPlaybackRate() {
        guard currentTrack?.remix == nil else { return }
        engine.apply(currentRemix)
        refreshNowPlayingProgress()
    }

    /// Ремикс играющего трека: скорость, тон и эхо.
    var currentRemix: RemixSettings {
        currentTrack?.remix ?? RemixSettings(speed: defaults.double(forKey: AppSettings.playbackRate))
    }

    /// Трек звучит не так, как записан.
    var hasRemix: Bool {
        !(currentTrack?.remix ?? .neutral).isNeutral
    }

    /// Ручку повернули. Значение уходит в звук тем же кадром и остаётся у трека:
    /// завтра он заиграет так же. Файл при этом не меняется — вся обработка живёт
    /// в графе и существует, только пока трек играет.
    func updateRemix(_ settings: RemixSettings) {
        let settings = settings.clamped()
        currentTrack?.remix = settings
        engine.apply(settings)
        refreshNowPlayingProgress()
    }

    /// Вернуть трек к тому, как он записан.
    func resetRemix() {
        currentTrack?.remix = nil
        engine.apply(currentRemix)
        refreshNowPlayingProgress()
    }

    /// Прыжок к треку из экрана очереди.
    func jump(to index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        playCurrent()
    }

    /// Файл доиграл до конца. Зовёт `PlaybackEngine`, уже с главного потока.
    private func handleTrackFinished() {
        // Таймер сна «до конца трека»: дослушали — и тишина, очередь не трогаем.
        if stopsAfterCurrentTrack {
            stopsAfterCurrentTrack = false
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
            guard let self, self.engine.hasTrack else { return }
            self.currentTime = self.engine.currentTime
            self.countPlayIfNeeded()
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    /// Прослушиванием считается полминуты звука (или половина трека, если он короче),
    /// а не факт запуска: иначе перебор очереди накрутил бы счётчик всем подряд.
    private func countPlayIfNeeded() {
        // Уже засчитанный трек продолжает копить секунды: событие закрывается не по
        // порогу, а когда с трека уходят.
        if let currentEvent {
            currentEvent.seconds = currentTime
            return
        }

        guard !didCountCurrentPlay, let track = currentTrack else { return }

        let threshold = duration > 0 ? min(30, duration / 2) : 30
        guard currentTime >= threshold else { return }

        didCountCurrentPlay = true
        track.playCount += 1

        let event = PlayEvent(track: track, seconds: currentTime)
        modelContext?.insert(event)
        currentEvent = event
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func startMeterTimer() {
        stopMeterTimer()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self, self.engine.hasTrack else { return }

            let db = self.engine.levelDecibels
            let normalized = (db - self.meterFloor) / (0 - self.meterFloor)
            self.level = min(max(normalized, 0), 1)
            self.updatePunch()
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    /// Пересчёт «дыхания» по свежему замеру громкости, 30 раз в секунду.
    private func updatePunch() {
        // Вспышка мгновенная, гаснет плавно — так удары читаются как удары.
        if level > glow {
            glow = level
        } else {
            glow += (level - glow) * 0.06
        }

        if isRangeCalibrated {
            // Границы мгновенно раздвигаются наружу и медленно сползают внутрь.
            loud = max(glow, loud + (glow - loud) * 0.004)
            quiet = min(glow, quiet + (glow - quiet) * 0.004)
        } else {
            // Первый замер нового трека задаёт коридор вокруг его реальной громкости.
            // Без этого стартовые 0...1 несколько секунд врут в сторону максимума.
            quiet = max(glow - 0.15, 0)
            loud = min(glow + 0.15, 1)
            isRangeCalibrated = true
        }

        // `span` не даёт делить на почти-ноль: на ровном месте фон должен замереть,
        // а не раздувать микроскопические колебания до полного размаха.
        let span = max(loud - quiet, 0.12)
        punch = min(max((glow - quiet) / span, 0), 1)
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
            // Скорость настоящая: по ней экран блокировки досчитывает время между
            // обновлениями, и с чужим числом оно поехало бы.
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? currentRemix.speed : 0.0,
            MPMediaItemPropertyPlaybackDuration: engine.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: engine.currentTime
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
    
    /// Только время и скорость. Полный `updateNowPlayingInfo` заново собирает
    /// обложку, а ручку крутят десятками кадров в секунду.
    private func refreshNowPlayingProgress() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = engine.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? currentRemix.speed : 0.0
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
        engine.seek(to: clamped)
        currentTime = clamped
        updateNowPlayingInfo()
    }

    func restore(_ tracks: [Track], current filename: String) {
        queue = tracks
        currentIndex = tracks.firstIndex { $0.filename == filename } ?? 0
        refreshPalette()
    }

    /// Разбор обложки уводится в фоновую задачу: она декодируется и сжимается,
    /// а смена трека не должна ради этого подвисать.
    private func refreshPalette() {
        guard let track = currentTrack, let data = track.displayArtwork else {
            palette = .fallback
            return
        }

        let filename = track.filename

        Task { @MainActor in
            let found = await Task.detached(priority: .utility) {
                UIImage(data: data)?.coverPalette
            }.value

            // Пока считали, трек мог смениться — тогда эти цвета уже не к месту.
            guard currentTrack?.filename == filename else { return }

            palette = found ?? .fallback
        }
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
    /// «Очистить дальше» на экране очереди: сыгранное и текущий трек остаются,
    /// уходит только то, что ждёт впереди.
    func clearUpcoming() {
        guard queue.indices.contains(currentIndex), currentIndex + 1 < queue.count else { return }

        let removedIDs = Set(queue[(currentIndex + 1)...].map(\.id))
        queue.removeSubrange((currentIndex + 1)...)
        originalQueue.removeAll { removedIDs.contains($0.id) }

        persistQueue()
    }

    private func persistQueue() {
        defaults.set(currentTrack?.filename, forKey: Keys.lastTrack)
        defaults.set(queue.map(\.filename), forKey: Keys.queue)
    }

    private func persistModes() {
        defaults.set(repeatMode.rawValue, forKey: Keys.repeatMode)
        defaults.set(isShuffled, forKey: Keys.isShuffled)
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

            guard defaults.bool(forKey: AppSettings.resumeAfterInterruption) else { return }

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
              reason == .oldDeviceUnavailable,
              defaults.bool(forKey: AppSettings.pauseOnDisconnect) else { return }

        pause()
    }
    
}
