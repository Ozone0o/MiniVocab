import SwiftUI
import AVFAudio

/// Main floating word card view.
///
/// Two states:
/// - Question State: shows word + example (if available)
/// - Answer State: shows word + phonetic + meaning + rating buttons
@MainActor
public struct FloatingWordView: View {
    @State private var vm: FloatingWordViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var settingsStore = SettingsStore.shared
    @State private var isSpeaking = false

    public init(vm: FloatingWordViewModel) {
        _vm = State(initialValue: vm)
    }

    @State private var windowSize: CGSize = CGSize(width: 320, height: 190)
    @State private var isSettingPressed = false

    public var body: some View {
        VStack(spacing: 0) {
            // Settings button (top-right)
            settingsButton

            // Content area
            if vm.sessionComplete {
                dailyCompleteView
            } else if !vm.hasWordBooks() {
                noWordBookView
            } else if let word = vm.currentWord {
                contentView(word: word)
            } else {
                loadingView
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .opacity(windowOpacity())
        .background(draggableBackground)
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button(action: { isSettingPressed = true }) {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .padding(8)
        .sheet(isPresented: $isSettingPressed) {
            SettingsView()
        }
    }

    // MARK: - Content Views

    private func contentView(word: Word) -> some View {
        VStack(spacing: 8) {
            Spacer()

            // Word
            HStack(spacing: 8) {
                Text(word.text)
                    .font(.system(size: 28, weight: .medium, design: .default))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Speaker button
                Button(action: { speak(word.text) }) {
                    Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isSpeaking)
            }

            // Question State: show example
            if !vm.isAnswerRevealed, let example = word.example {
                Text(example)
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
            }

            Spacer()

            // Answer State: show phonetic, meaning, rating buttons
            if vm.isAnswerRevealed {
                VStack(spacing: 8) {
                    if let phonetic = word.phonetic {
                        Text(phonetic)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Text(word.meaning ?? "暂无释义")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                }

                ratingButtons
            } else {
                // Invisible tap target in question state
                Color.clear
                    .frame(height: 40)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.revealAnswer()
                    }
            }
        }
        .padding(.bottom, vm.isAnswerRevealed ? 8 : 16)
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        HStack(spacing: 12) {
            ForEach(Rating.allCases, id: \.rawValue) { rating in
                Button(action: { vm.rate(rating) }) {
                    Text(rating.localized)
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(ratingBg(rating))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func ratingBg(_ rating: Rating) -> Color {
        switch rating {
        case .again: return Color.red.opacity(0.8)
        case .hard: return Color.orange.opacity(0.8)
        case .good: return Color.green.opacity(0.8)
        case .easy: return Color.blue.opacity(0.8)
        }
    }

    // MARK: - Placeholder Views

    private var noWordBookView: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.open")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("请先在设置中导入词书")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dailyCompleteView: some View {
        VStack(spacing: 12) {
            Text("今日完成")
                .font(.system(size: 18, weight: .medium))
            Text("明天再来吧")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Draggable Background

    private var draggableBackground: some View {
        Color.clear
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.secondary.opacity(0.3), lineWidth: 1)
                    )
            )
    }

    // MARK: - Window Opacity

    private func windowOpacity() -> Double {
        settingsStore.windowOpacity
    }

    // MARK: - Pronunciation

    private func speak(_ text: String) {
        guard !text.isEmpty, !isSpeaking else { return }
        isSpeaking = true
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        AVSpeechSynthesizer().speak(utterance)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSpeaking = false
        }
    }
}
