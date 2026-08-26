import SwiftUI
import SwiftData

@main
struct MiniVocabApp: App {
    let persistenceController = PersistenceController()
    let scheduler = SimpleSpacedRepetitionScheduler()
    @ObservedObject private var settingsStore = SettingsStore.shared

    let sessionManager: StudySessionManager
    let viewModel: FloatingWordViewModel

    init() {
        self.sessionManager = StudySessionManager(persistence: persistenceController, scheduler: scheduler)
        let wordBookService = WordBookService(persistence: persistenceController)
        wordBookService.sessionManager = sessionManager
        self.viewModel = FloatingWordViewModel(sessionManager: sessionManager, focusManager: FocusManager())

        // Restore active book session on launch
        try? sessionManager.restoreActiveBook()
    }

    var body: some Scene {
        WindowGroup {
            FloatingWordView(vm: viewModel, settingsStore: settingsStore, persistence: persistenceController)
                .onAppear {
                    viewModel.loadNextWord()
                }
        }
        .modelContainer(persistenceController.modelContainer)
    }
}
