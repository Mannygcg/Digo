import AppKit
import SwiftUI

final class HUDWindowController {
    private let panel: NSPanel
    private let viewModel = HUDViewModel()

    init() {
        let frame = NSRect(x: 0, y: 0, width: 400, height: 60)
        let hosting = NSHostingView(rootView: HUDView(viewModel: viewModel))
        hosting.frame = frame

        panel = NSPanel(contentRect: frame, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.contentView = hosting
    }

    func show() {
        viewModel.text = ""
        positionPanel()
        panel.orderFrontRegardless()
    }

    func update(text: String) {
        viewModel.text = text
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.minY + 80
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
