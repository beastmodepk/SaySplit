import Foundation
import Combine
import Speech
import AVFoundation

/// On-device voice capture for the command box, using
/// SFSpeechRecognizer + AVAudioEngine (the iOS counterpart of the web
/// version's browser SpeechRecognition).
///
/// Behaviour contract:
/// - Permissions (speech recognition + microphone) are requested only
///   when the user taps the mic button.
/// - If either is denied, restricted, or the recognizer is unavailable,
///   recording does not start and `statusMessage` explains why; the
///   typed command box always remains available.
/// - The transcript is published live into `transcript`; the user still
///   reviews it, taps Parse, and confirms an editable preview before
///   anything is saved.
@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var statusMessage: String? = nil

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    // MARK: - Permissions

    /// Requests speech-recognition and microphone permission; returns
    /// true only when both are granted. Sets `statusMessage` otherwise.
    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            statusMessage = "Speech recognition is not allowed. "
                + "You can enable it in Settings → SaySplit, or just type the command instead."
            return false
        }

        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        guard micGranted else {
            statusMessage = "Microphone access is not allowed. "
                + "You can enable it in Settings → SaySplit, or just type the command instead."
            return false
        }
        statusMessage = nil
        return true
    }

    // MARK: - Recording

    func toggleRecording() {
        if isRecording {
            stop()
        } else {
            Task { await start() }
        }
    }

    func start() async {
        guard !isRecording else { return }
        guard let recognizer = recognizer, recognizer.isAvailable else {
            statusMessage = "Speech recognition is unavailable right now — please type the command instead."
            return
        }
        guard await requestPermissions() else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let newRequest = SFSpeechAudioBufferRecognitionRequest()
            newRequest.shouldReportPartialResults = true
            request = newRequest

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                newRequest.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            transcript = ""

            task = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
                guard let self = self else { return }
                Task { @MainActor in
                    if let result = result {
                        self.transcript = result.bestTranscription.formattedString
                        if result.isFinal { self.stop() }
                    }
                    if error != nil {
                        self.stop()
                    }
                }
            }
            isRecording = true
            statusMessage = nil
        } catch {
            statusMessage = "Could not start the microphone (\(error.localizedDescription)). "
                + "Typing the command works just the same."
            stop()
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
