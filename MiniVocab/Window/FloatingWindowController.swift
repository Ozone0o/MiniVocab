import Foundation
import AppKit

/// Lightweight window configurator — no longer creates a window.
/// Configures the real window created by WindowGroup.
@MainActor
final class FloatingWindowConfigurator {
    weak var window: NSWindow?
    let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func configure(window: NSWindow) {
        // Already configured this window — just refresh dynamic properties
        guard self.window !== window else {
            applyAlwaysOnTop()
            applyOpacity()
            return
        }

        self.window = window
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .resizable, .closable, .fullSizeContentView]
        window.collectionBehavior = [.canJoinAllSpaces]
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isRestorable = false
        window.minSize = NSSize(width: 150, height: 150)

        applyAlwaysOnTop()
        applyOpacity()
    }

    func applyAlwaysOnTop() {
        guard let window = window else { return }
        window.level = settingsStore.alwaysOnTop ? .floating : .normal
    }

    func applyOpacity() {
        guard let window = window else { return }
        window.alphaValue = CGFloat(settingsStore.windowOpacity)
    }

    func saveWindowFrame() {
        settingsStore.windowFrame = window?.frame
    }
}

// MARK: - FocusManager

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
