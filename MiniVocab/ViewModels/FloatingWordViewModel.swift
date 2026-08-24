import Foundation
import SwiftUI

/// ViewModel for the floating word card. Manages the Question/Answer state machine.
@Observable
@MainActor
public final class FloatingWordViewModel {
    var currentWord: Word?
    var isAnswerRevealed = false
    var sessionComplete = false
    var errorMessage: String?

    private let sessionManager: StudySessionManager
    private let focusManager: FocusManager

    init(sessionManager: StudySessionManager, focusManager: FocusManager) {
        self.sessionManager = sessionManager
        self.focusManager = focusManager
    }

    // MARK: - Actions

    /// User clicked the word/card — reveal answer
    func revealAnswer() {
        focusManager.beginInteraction()
        isAnswerRevealed = true
    }

    /// Record a rating and load next word
    func rate(_ rating: Rating) {
        guard let word = currentWord else { return }
        isAnswerRevealed = false

        do {
            currentWord = try sessionManager.recordRating(word: word, rating: rating)
            sessionComplete = currentWord == nil

            // Restore focus after rating
            focusManager.finishInteraction()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Load the next word from the session
    func loadNextWord() {
        do {
            currentWord = try sessionManager.nextWord()
            sessionComplete = currentWord == nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Check if there are any word books imported
    func hasWordBooks() -> Bool {
        if let result = try? sessionManager.persistence.fetchEnabledWordBooks(),
           result.isEmpty == false {
            return true
        }
        return false
    }
}
