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
        static let wordOrderMode = "minvocab_wordOrderMode"
        static let wordsPerRound = "minvocab_wordsPerRound"
        static let roundsPerGroup = "minvocab_roundsPerGroup"
        static let selectedBookID = "minvocab_selectedBookID"
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

    @Published var wordOrderMode: String {
        didSet { defaults.set(wordOrderMode, forKey: Key.wordOrderMode) }
    }

    @Published var wordsPerRound: Int {
        didSet { defaults.set(wordsPerRound, forKey: Key.wordsPerRound) }
    }

    @Published var roundsPerGroup: Int {
        didSet { defaults.set(roundsPerGroup, forKey: Key.roundsPerGroup) }
    }

    @Published var selectedBookID: String? {
        didSet { defaults.set(selectedBookID, forKey: Key.selectedBookID) }
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
        self.wordOrderMode = defaults.string(forKey: Key.wordOrderMode) ?? "sequential"
        if defaults.object(forKey: Key.wordOrderMode) == nil {
            self.wordOrderMode = "sequential"
        }
        var wpr = defaults.integer(forKey: Key.wordsPerRound)
        if defaults.object(forKey: Key.wordsPerRound) == nil { wpr = 20 }
        if wpr < 1 { wpr = 1 }
        if wpr > 100 { wpr = 100 }
        self.wordsPerRound = wpr

        var rpg = defaults.integer(forKey: Key.roundsPerGroup)
        if defaults.object(forKey: Key.roundsPerGroup) == nil { rpg = 5 }
        if rpg < 1 { rpg = 1 }
        if rpg > 20 { rpg = 20 }
        self.roundsPerGroup = rpg
        self.selectedBookID = defaults.string(forKey: Key.selectedBookID)
    }
}
