import Foundation
import AVFoundation
import CoreGraphics
import AppKit

/// Tracks and requests the two TCC permissions the app needs:
/// microphone (both modes) and screen recording (ScreenCaptureKit system audio, Mode B).
@MainActor
final class PermissionsManager: ObservableObject {
    @Published var micGranted: Bool = false
    @Published var screenGranted: Bool = false

    init() { refresh() }

    func refresh() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        // CGPreflightScreenCaptureAccess returns whether the app already has permission,
        // without prompting.
        screenGranted = CGPreflightScreenCaptureAccess()
    }

    /// Prompt for microphone access (only shows the system dialog the first time).
    func requestMicrophone() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .authorized {
            micGranted = true
            return true
        }
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        micGranted = granted
        return granted
    }

    /// Prompt for screen-recording access. Needed only for Mode B (system audio capture).
    func requestScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            screenGranted = true
            return true
        }
        // Triggers the system prompt; returns current state. Users may need to relaunch
        // after granting, which is standard macOS TCC behavior.
        let granted = CGRequestScreenCaptureAccess()
        screenGranted = granted
        return granted
    }

    func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
