import Foundation
import AppKit

/// Manages the floating word card window with proper always-on-top and resize behavior.
final class FloatingWindowController: NSWindowController {

    private let panel: FloatingPanel

    /// The settings store used to configure window behavior
    var settingsStore: SettingsStore? {
        didSet {
            applyAlwaysOnTop()
            applyOpacity()
        }
    }

    // MARK: - Initialization

    override init(window: NSWindow?) {
        panel = FloatingPanel(contentRect: CGRect(x: 0, y: 0, width: 320, height: 190),
                              styleMask: [.borderless, .fullSizeContentView, .resizable],
                              backing: .buffered,
                              defer: false)
        super.init(window: panel)

        panel.collectionBehavior = .canJoinAllSpaces
        panel.hasShadow = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    func show() {
        panel.orderFrontRegardless()

        if let savedFrame = settingsStore?.windowFrame {
            panel.setFrame(savedFrame, display: true)
        }
        applyAlwaysOnTop()
        applyOpacity()
    }

    func hide() {
        panel.orderOut(nil)
    }

    // MARK: - Settings Application

    private func applyAlwaysOnTop() {
        guard let store = settingsStore else { return }
        if store.alwaysOnTop {
            panel.level = .floating
            panel.collectionBehavior.insert(.canJoinAllSpaces)
        } else {
            panel.level = .normal
            panel.collectionBehavior.remove(.canJoinAllSpaces)
        }
    }

    private func applyOpacity() {
        guard let store = settingsStore else { return }
        panel.alphaValue = CGFloat(store.windowOpacity)
    }

    // MARK: - Window Frame Save

    func saveWindowFrame() {
        guard let _ = settingsStore else { return }
        settingsStore?.windowFrame = panel.frame
    }

    // MARK: - Font Size Dispatch

    func applyFontSize(_ fontSize: Int) {
        NotificationCenter.default.post(
            name: .settingsDidChange,
            object: nil,
            userInfo: ["fontSize": fontSize]
        )
    }

    func applyOpacityValue(_ opacity: Double) {
        panel.alphaValue = CGFloat(opacity)
    }
}

// MARK: - FloatingPanel

/// A custom NSPanel that supports drag-to-move and resize simultaneously.
final class FloatingPanel: NSPanel {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        self.isMovable = true
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.isRestorable = false
    }
}

// MARK: - WindowFocusManager

/// Manages application focus behavior for the floating window.
@MainActor
public final class FocusManager: @unchecked Sendable {
    private var previousApp: NSRunningApplication?

    public init() {
        self.previousApp = NSWorkspace.shared.frontmostApplication
    }

    func beginInteraction() {
        let current = NSWorkspace.shared.frontmostApplication
        if let current, Bundle.main.bundleIdentifier != current.bundleIdentifier {
            previousApp = current
        }
    }

    func finishInteraction() {
        restorePreviousApplication()
    }

    func restorePreviousApplication() {
        guard let app = previousApp, !app.isTerminated else {
            NSApp.deactivate()
            return
        }

        NSApp.deactivate()
        app.activate(options: [.activateAllWindows])
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}
