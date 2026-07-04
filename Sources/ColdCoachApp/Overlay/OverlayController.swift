import AppKit
import SwiftUI

/// Manages the always-on-top, non-activating floating panel that shows coaching cards
/// over whatever app the rep is calling from.
///
/// Note: the classic screen-share "stealth" exclusion (`sharingType = .none`) is broken on
/// macOS 15+, so the overlay is assumed visible if the user shares their whole screen. For
/// audio-only cold calls that is not a concern.
@MainActor
final class OverlayController {
    private var panel: NSPanel?
    let model: OverlayModel

    init(model: OverlayModel) {
        self.model = model
    }

    func show(opacity: Double = 0.95) {
        if panel == nil {
            let hosting = NSHostingController(rootView: CoachingOverlayView(model: model, opacity: opacity))
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
                styleMask: [.nonactivatingPanel, .borderless, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = hosting
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            positionBottomTrailing(panel)
            self.panel = panel
        }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func close() {
        panel?.close()
        panel = nil
    }

    private func positionBottomTrailing(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let margin: CGFloat = 24
        let origin = NSPoint(
            x: visible.maxX - size.width - margin,
            y: visible.minY + margin
        )
        panel.setFrameOrigin(origin)
    }
}
