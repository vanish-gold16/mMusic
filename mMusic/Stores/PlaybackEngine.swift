import AVFoundation
import Foundation

/// Звуковой тракт приложения: файл → скорость и тон → эхо → выход.
///
/// Пришёл на смену `AVAudioPlayer`. Тот умеет менять только темп, сохраняя тон,
/// а ремикс — это как раз тон и эхо, которые крутят прямо во время игры: узлы
/// графа принимают новые параметры на лету, без паузы и перезапуска файла.
/// Сам файл при этом не трогается — на диске ничего не пересчитывается.
///
/// Взамен приходится считать самому всё, что `AVAudioPlayer` давал даром:
/// позицию в треке, момент его окончания и громкость для «дыхания» фона.
final class PlaybackEngine {

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    /// Скорость и тон в одном узле: `rate` тянет время, `pitch` — высоту, и они
    /// независимы. «Как на виниле» получается связкой чисел в `RemixSettings`,
    /// а не отдельным узлом.
    private let timePitch = AVAudioUnitTimePitch()
    private let reverb = AVAudioUnitReverb()

    private var file: AVAudioFile?
    /// Формат, под который собран граф. Узлы соединяются форматом файла, поэтому
    /// на треке с другой частотой дискретизации цепочку надо пересобрать.
    private var connectedFormat: AVAudioFormat?

    /// Кадр, с которого запущено текущее расписание: `playerTime` считает от нуля
    /// с каждого запуска узла, а нам нужна позиция в файле.
    private var startFrame: AVAudioFramePosition = 0
    /// Позиция, замороженная на паузе: у остановленного узла своего времени нет.
    private var frozenTime: TimeInterval = 0
    private var hasSchedule = false

    /// Номер расписания. Обрыв по перемотке или остановке тоже вызывает completion —
    /// без счётчика перемотка выглядела бы как «трек кончился» и переключала бы
    /// на следующий.
    private var generation = 0

    /// Громкость последнего куска звука в децибелах. Пишет аудиопоток, читает
    /// таймер на главном.
    ///
    /// Без синхронизации намеренно: замок на потоке рендеринга может заставить его
    /// ждать главный — а тот в это время рисует экран, и звук успевает щёлкнуть.
    /// Здесь это безопасно: восьмибайтовое число пишется целиком, и потеря одного
    /// замера из тридцати в секунду ничего не значит.
    private nonisolated(unsafe) var levelInDecibels: Double = -160

    /// Трек доиграл до конца. Зовётся на главном потоке.
    var onFinish: (() -> Void)?

    private(set) var isPlaying = false

    init() {
        engine.attach(playerNode)
        engine.attach(timePitch)
        engine.attach(reverb)

        // Пресет ставится один раз: смена пресета пересобирает отклик зала и слышна
        // щелчком, а вот `wetDryMix` можно крутить сколько угодно — он плавный.
        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 0

        // Первым делом — обращение к mainMixerNode: оно соединяет микшер с выходом.
        // Без единственной связи граф пустой, и `prepare()` роняет приложение
        // на «inputNode != nullptr || outputNode != nullptr».
        installMeterTap()
        engine.prepare()
        observeConfigurationChange()
    }

    deinit {
        engine.mainMixerNode.removeTap(onBus: 0)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Что играет

    var duration: TimeInterval {
        guard let file else { return 0 }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    /// Позиция внутри трека. Узел считает кадры, которые вытянул из файла, поэтому
    /// это именно место в записи, а не прошедшее время: на половинной скорости
    /// секунда реального времени двигает ползунок на полсекунды — так и надо.
    var currentTime: TimeInterval {
        guard isPlaying,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else { return frozenTime }

        let seconds = Double(startFrame + playerTime.sampleTime) / playerTime.sampleRate
        return min(max(seconds, 0), duration)
    }

    var hasTrack: Bool { file != nil }

    /// Громкость для «дыхания» фона, в тех же децибелах, что раньше давал
    /// `averagePower(forChannel:)`.
    var levelDecibels: Double { levelInDecibels }

    // MARK: - Управление

    /// Открывает файл и готовит граф. Звук не начинается — для этого `play()`.
    func load(_ url: URL) throws {
        stop()

        let file = try AVAudioFile(forReading: url)
        self.file = file
        startFrame = 0
        frozenTime = 0
        hasSchedule = false

        connect(to: file.processingFormat)
    }

    func play() {
        guard file != nil else { return }

        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            print("Audio engine start error: \(error)")
            return
        }

        // Расписание переживает паузу: после неё узел просто продолжает с места,
        // а заново планировать нужно только после загрузки и перемотки.
        if !hasSchedule {
            // С конца играть нечего, и «play» в этом положении означает «сначала».
            if let file, startFrame >= file.length {
                startFrame = 0
                frozenTime = 0
            }
            schedule()
        }

        playerNode.play()
        isPlaying = true
    }

    func pause() {
        guard isPlaying else { return }

        // Порядок важен: время замораживается, пока узел ещё идёт, иначе
        // `currentTime` уже вернёт замороженное значение и запишет само себя.
        frozenTime = currentTime
        playerNode.pause()
        isPlaying = false
        engine.pause()
    }

    /// Полная остановка: файл забыт, граф свободен.
    func stop() {
        generation += 1
        playerNode.stop()
        engine.stop()
        isPlaying = false
        hasSchedule = false
        frozenTime = 0
        startFrame = 0
        file = nil
        levelInDecibels = -160
    }

    func seek(to time: TimeInterval) {
        guard let file else { return }

        let wasPlaying = isPlaying
        let clamped = min(max(time, 0), duration)

        // Счётчик увеличивается до `stop()`: тот дёрнет completion оборванного
        // расписания, и по старому номеру он будет отброшен.
        generation += 1
        playerNode.stop()
        isPlaying = false
        hasSchedule = false

        startFrame = AVAudioFramePosition(clamped * file.processingFormat.sampleRate)
        frozenTime = clamped

        if wasPlaying { play() }
    }

    /// Новые положения ручек. Зовётся и на смене трека, и на каждое движение
    /// пальца — узлы принимают значения на ходу и сглаживают их сами.
    func apply(_ remix: RemixSettings) {
        let remix = remix.clamped()

        timePitch.rate = Float(remix.speed)
        // Тон задаётся в центах: сотая доля полутона.
        timePitch.pitch = Float(remix.effectivePitch * 100)
        reverb.wetDryMix = Float(remix.reverb)

        // Обход, пока ручки в нуле. Растяжение времени — фазовый вокодер: он честно
        // работает и на скорости 1.0, просто впустую. На устройстве этот холостой
        // ход отъедает запас у потока рендеринга, и звук начинает заикаться.
        timePitch.bypass = abs(remix.speed - 1) < 0.005 && abs(remix.effectivePitch) < 0.05
        reverb.bypass = remix.reverb < 0.5
    }

    // MARK: - Граф

    private func connect(to format: AVAudioFormat) {
        guard connectedFormat != format else { return }

        engine.connect(playerNode, to: timePitch, format: format)
        engine.connect(timePitch, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        connectedFormat = format

        // Отвод для замера громкости живёт на выходе микшера и переживает пересборку,
        // но формат шины после неё другой — проще поставить заново.
        installMeterTap()
    }

    private func schedule() {
        guard let file else { return }

        // Узел считает время от собственного старта, а не от начала расписания,
        // и `pause()` этот счётчик не трогает — обнуляет его только `stop()`.
        // Доигравший трек оставляет счётчик на своём конце, поэтому перед новым
        // расписанием узел надо остановить: иначе `currentTime` считал бы позицию
        // от конца предыдущего проигрывания — звук с начала, ползунок в конце.
        // Счётчик расписаний растёт до остановки, чтобы её completion был отброшен.
        generation += 1
        playerNode.stop()

        let frames = AVAudioFrameCount(max(file.length - startFrame, 0))
        guard frames > 0 else {
            finish()
            return
        }

        let token = generation

        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frames,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            // Коллбэк приходит с аудиопотока, а дальше начинается очередь и модели.
            DispatchQueue.main.async {
                guard let self, token == self.generation else { return }
                self.finish()
            }
        }

        hasSchedule = true
    }

    private func finish() {
        // Встаём ровно на конце: следующий `play()` увидит это и начнёт сначала.
        startFrame = file?.length ?? startFrame
        frozenTime = duration
        isPlaying = false
        hasSchedule = false
        onFinish?()
    }

    // MARK: - Громкость

    /// Замер по выходу микшера, а не по самому файлу: эхо и скорость слышны в фоне
    /// так же, как в наушниках.
    private func installMeterTap() {
        let mixer = engine.mainMixerNode
        mixer.removeTap(onBus: 0)

        mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }

            // Среднеквадратичное: громкость куска, а не случайный отсчёт из него.
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { return }

            var sum: Float = 0
            for index in 0..<frames {
                let sample = channel[index]
                sum += sample * sample
            }

            let rms = (sum / Float(frames)).squareRoot()
            // Нижний порог не даёт логарифму уйти в минус бесконечность на тишине.
            self?.levelInDecibels = 20 * log10(max(Double(rms), 1e-7))
        }
    }

    /// Наушники, AirPlay, звонок: система может перестроить выход под собой,
    /// и тогда движок останавливается сам. Собираем граф заново и возвращаемся
    /// на то же место трека.
    private func observeConfigurationChange() {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            let position = self.currentTime
            let wasPlaying = self.isPlaying

            self.isPlaying = false
            self.hasSchedule = false
            self.connectedFormat = nil

            if let format = self.file?.processingFormat {
                self.connect(to: format)
            }

            self.seek(to: position)
            if wasPlaying { self.play() }
        }
    }
}
