import Foundation

/// Persistent settings store backed by UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults: UserDefaults

    // MARK: - Keys

    private enum Key {
        static let fontSize = "minvocab_fontSize"
        static let windowOpacity = "minvocab_windowOpacity"
        static let alwaysOnTop = "minvocab_alwaysOnTop"
        static let launchAtLogin = "minvocab_launchAtLogin"
        static let windowFrameOriginX = "minvocab_windowFrameOriginX"
        static let windowFrameOriginY = "minvocab_windowFrameOriginY"
        static let windowFrameWidth = "minvocab_windowFrameWidth"
        static let windowFrameHeight = "minvocab_windowFrameHeight"
    }

    // MARK: - Properties

    @Published var fontSize: Int {
        didSet { defaults.set(fontSize, forKey: Key.fontSize) }
    }

    @Published var windowOpacity: Double {
        didSet { defaults.set(windowOpacity, forKey: Key.windowOpacity) }
    }

    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Key.alwaysOnTop) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    var windowFrame: NSRect? {
        get {
            let x = defaults.double(forKey: Key.windowFrameOriginX)
            let y = defaults.double(forKey: Key.windowFrameOriginY)
            let w = defaults.double(forKey: Key.windowFrameWidth)
            let h = defaults.double(forKey: Key.windowFrameHeight)
            if w == 0 && h == 0 { return nil }
            return NSRect(x: x, y: y, width: w, height: h)
        }
        set {
            if let frame = newValue {
                defaults.set(frame.origin.x, forKey: Key.windowFrameOriginX)
                defaults.set(frame.origin.y, forKey: Key.windowFrameOriginY)
                defaults.set(frame.size.width, forKey: Key.windowFrameWidth)
                defaults.set(frame.size.height, forKey: Key.windowFrameHeight)
            }
        }
    }

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.fontSize = defaults.integer(forKey: Key.fontSize)
        if defaults.object(forKey: Key.fontSize) == nil {
            self.fontSize = 16
        }
        self.windowOpacity = defaults.double(forKey: Key.windowOpacity)
        if defaults.object(forKey: Key.windowOpacity) == nil {
            self.windowOpacity = 1.0
        }
        self.alwaysOnTop = defaults.bool(forKey: Key.alwaysOnTop)
        if defaults.object(forKey: Key.alwaysOnTop) == nil {
            self.alwaysOnTop = true
        }
        self.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        if defaults.object(forKey: Key.launchAtLogin) == nil {
            self.launchAtLogin = false
        }
    }
}
