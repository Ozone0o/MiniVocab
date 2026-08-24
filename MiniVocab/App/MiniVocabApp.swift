import SwiftUI
import SwiftData

@main
struct MiniVocabApp: App {
    let persistenceController = PersistenceController()
    let scheduler = SimpleSpacedRepetitionScheduler()

    @State private var sessionManager: StudySessionManager
    @State private var focusManager = FocusManager()
    @State private var viewModel: FloatingWordViewModel
    @StateObject private var settingsStore = SettingsStore.shared
    @State private var floatingWindowController: FloatingWindowController?

    init() {
        let persistence = PersistenceController()
        let scheduler = SimpleSpacedRepetitionScheduler()
        let sessionMgr = StudySessionManager(persistence: persistence, scheduler: scheduler)
        _sessionManager = State(initialValue: sessionMgr)
        _focusManager = State(initialValue: FocusManager())
        _viewModel = State(initialValue: FloatingWordViewModel(
            sessionManager: sessionMgr,
            focusManager: FocusManager()
        ))

        // Create the floating window
        let windowController = FloatingWindowController()
        windowController.settingsStore = settingsStore
        _floatingWindowController = State(initialValue: windowController)
    }

    var body: some Scene {
        WindowGroup {
            FloatingWordView(vm: viewModel)
                .frame(width: 320, height: 190)
                .onAppear {
                    viewModel.loadNextWord()
                    floatingWindowController?.showWindow(self)
                }
                .keyboardShortcut(.space, modifiers: [])
                .keyboardShortcut(KeyEquivalent("1"), modifiers: [])
                .keyboardShortcut(KeyEquivalent("2"), modifiers: [])
                .keyboardShortcut(KeyEquivalent("3"), modifiers: [])
                .keyboardShortcut(KeyEquivalent("4"), modifiers: [])
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .modelContainer(persistenceController.modelContainer)

        Settings {
            SettingsView()
        }
    }
}
