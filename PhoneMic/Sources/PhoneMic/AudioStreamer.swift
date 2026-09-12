import Foundation
import AVFoundation
import Network

/// Captures mic audio and streams raw PCM16 mono over a TCP socket to the PC.
/// Designed to survive: other apps/system sounds playing audio, phone calls ending,
/// route changes (headphones/Bluetooth plugged in/out), and app backgrounding.
final class AudioStreamer: NSObject, ObservableObject {

    @Published var status: String = "Idle"
    @Published var isStreaming: Bool = false

    private let engine = AVAudioEngine()
    private var connection: NWConnection?
    private var host: String = ""
    private var port: UInt16 = 50505
    private var wantsStreaming = false
    private var reconnectWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        configureNotifications()
    }

    // MARK: - Public controls

    func start(host: String, port: UInt16) {
        self.host = host
        self.port = port
        self.wantsStreaming = true
        activateSession()
        connect()
        startTapIfNeeded()
    }

    func stop() {
        wantsStreaming = false
        reconnectWorkItem?.cancel()
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        connection?.cancel()
        connection = nil
        isStreaming = false
        status = "Stopped"
    }

    // MARK: - Audio session

    /// playAndRecord + mixWithOthers is the key: it lets the mic keep recording
    /// even while the phone plays audio (music, notifications, Siri, etc.)
    /// instead of iOS killing the record session.
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            status = "Session active"
        } catch {
            status = "Session error: \(error.localizedDescription)"
        }
    }

    private func configureNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleMediaReset),
                       name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard wantsStreaming,
              let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // Something took the session (e.g. an incoming call). Keep the socket
            // open; we'll resume the tap the moment the interruption ends.
            status = "Interrupted — waiting to resume"
        case .ended:
            activateSession()
            restartTap()
            status = "Resumed after interruption"
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        guard wantsStreaming else { return }
        // AirPods connect/disconnect, headphones plugged in, etc. Re-assert our
        // session + tap so streaming keeps going on the new route.
        activateSession()
        restartTap()
    }

    @objc private func handleMediaReset() {
        guard wantsStreaming else { return }
        activateSession()
        restartTap()
    }

    // MARK: - Tap / capture

    private func startTapIfNeeded() {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.send(buffer: buffer)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            status = "Engine start failed: \(error.localizedDescription)"
            scheduleReconnect()
        }
    }

    private func restartTap() {
        guard wantsStreaming else { return }
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        engine.reset()
        startTapIfNeeded()
    }

    private func send(buffer: AVAudioPCMBuffer) {
        guard let data = pcm16Data(from: buffer) else { return }
        guard let connection = connection, connection.state == .ready else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func pcm16Data(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        var samples = [Int16](repeating: 0, count: frameLength)
        let src = channelData[0]
        for i in 0..<frameLength {
            let clamped = max(-1.0, min(1.0, src[i]))
            samples[i] = Int16(clamped * Float(Int16.max))
        }
        return samples.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    // MARK: - Networking

    private func connect() {
        guard wantsStreaming else { return }
        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.sendFormatHeader()
                DispatchQueue.main.async {
                    self.isStreaming = true
                    self.status = "Streaming to \(self.host):\(self.port)"
                }
            case .failed, .cancelled:
                DispatchQueue.main.async {
                    self.isStreaming = false
                    self.status = "Disconnected — retrying"
                }
                self.scheduleReconnect()
            default:
                break
            }
        }
        conn.start(queue: .main)
    }

    private func sendFormatHeader() {
        let format = engine.inputNode.inputFormat(forBus: 0)
        var sampleRate = UInt32(format.sampleRate)
        var channels = UInt32(format.channelCount)
        var data = Data()
        withUnsafeBytes(of: &sampleRate) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &channels) { data.append(contentsOf: $0) }
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }

    private func scheduleReconnect() {
        guard wantsStreaming else { return }
        reconnectWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.wantsStreaming else { return }
            self.connect()
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }
}
