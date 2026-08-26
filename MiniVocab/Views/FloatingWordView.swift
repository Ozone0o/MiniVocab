import SwiftUI
import AVFAudio
import AppKit

/// Main floating word card view.
///
/// Two states:
/// - Question State: shows word + example (if available)
/// - Answer State: shows word + phonetic + meaning + rating buttons
@MainActor
public struct FloatingWordView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var vm: FloatingWordViewModel
    @State private var configurator: FloatingWindowConfigurator
    let wordBookService: WordBookService
    @State private var speechSynthesizer = AVSpeechSynthesizer()

    init(vm: FloatingWordViewModel, settingsStore: SettingsStore, persistence: PersistenceController) {
        _settingsStore = ObservedObject(wrappedValue: settingsStore)
        _vm = State(initialValue: vm)
        _configurator = State(initialValue: FloatingWindowConfigurator(settingsStore: settingsStore))
        self.wordBookService = WordBookService(persistence: persistence)
        self.wordBookService.sessionManager = vm.sessionManager
    }

    public var body: some View {
        ZStack {
            WindowAccessor(onFind: configurator.configure)

            VStack(spacing: 0) {
                settingsButton

                if vm.sessionComplete {
                    dailyCompleteView
                } else if !vm.hasWordBooks() {
                    noWordBookView
                } else if let word = vm.currentWord {
                    makeWordContent(word: word)
                } else {
                    loadingView
                }
            }
        }
        .onChange(of: settingsStore.windowOpacity) {
            configurator.applyOpacity()
        }
        .onChange(of: settingsStore.alwaysOnTop) { _, _ in
            configurator.applyAlwaysOnTop()
        }
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
            SettingsView(settingsStore: settingsStore, wordBookService: wordBookService, viewModel: vm)
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private func makeWordContent(word: Word) -> some View {
        let fontSize = Double(settingsStore.fontSize)
        let exampleFontSize = fontSize * 0.6
        let meaningFontSize = fontSize * 0.65

        VStack(spacing: 8) {
            Spacer()

            // Word + Speaker
            HStack(spacing: 8) {
                Text(word.text)
                    .font(.system(size: fontSize, weight: .medium, design: .default))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Button(action: { speak(word.text) }) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Question or Answer area
            if !vm.isAnswerRevealed {
                exampleArea(word: word, exampleFontSize: exampleFontSize)
            } else {
                answerArea(meaningFontSize: meaningFontSize)
            }

            Spacer()
        }
        .padding(.bottom, vm.isAnswerRevealed ? 8 : 16)
    }

    // MARK: - Question Area

    @ViewBuilder
    private func exampleArea(word: Word, exampleFontSize: Double) -> some View {
        let hasExample = !(word.example?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ?? true)

        if hasExample {
            Button(action: { reveal(word) }) {
                VStack(spacing: 8) {
                    Text(word.example!)
                        .font(.system(size: exampleFontSize, design: .serif))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(12)
                .background(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        } else {
            Button(action: { reveal(word) }) {
                Text("点击查看释义")
                    .font(.system(size: exampleFontSize))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(12)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private func reveal(_ word: Word) {
        vm.revealAnswer()
        speak(word.text)
    }

    // MARK: - Answer Area

    private func answerArea(meaningFontSize: Double) -> some View {
        VStack(spacing: 8) {
            if let word = vm.currentWord, let phonetic = word.phonetic {
                Text(phonetic)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Text(vm.currentWord?.meaning ?? "暂无释义")
                .font(.system(size: meaningFontSize))
                .multilineTextAlignment(.center)

            ratingButtons
        }
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
            Text("请先选择词书")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("在设置 → 词书中开始学习")
                .font(.system(size: 11))
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

    // MARK: - Pronunciation

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("en") }) {
            utterance.voice = voice
        }
        utterance.rate = 0.5
        speechSynthesizer.speak(utterance)
    }

    @State private var isSettingPressed = false
}

// MARK: - Window accessor

/// Finds the real NSWindow behind this SwiftUI View using viewDidMoveToWindow.
struct WindowAccessor: NSViewRepresentable {
    var onFind: (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowReaderNSView {
        let view = WindowReaderNSView(onWindow: onFind)
        return view
    }

    func updateNSView(_ nsView: WindowReaderNSView, context: Context) {
        // No-op: window is captured via viewDidMoveToWindow
    }
}

/// Custom NSView that reports itself when added to a window.
final class WindowReaderNSView: NSView {
    private let onWindow: (NSWindow) -> Void

    init(onWindow: @escaping (NSWindow) -> Void) {
        self.onWindow = onWindow
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onWindow(window)
        }
    }
}
