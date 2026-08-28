import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Settings window content with 3 sections: 外观, 词书, 数据
struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var wordBookEntries: [WordBookUIEntry] = []
    @State private var showFilePicker = false
    @State private var importMessage: String?
    @State private var deleteConfirmShown = false
    @State private var isLoading = false
    @State private var selectedTab = 0
    @State private var selectedBookForStudy: String?

    private let wordBookService: WordBookService
    let viewModel: FloatingWordViewModel
    @Environment(\.dismiss) private var dismiss

    init(settingsStore: SettingsStore, wordBookService: WordBookService, viewModel: FloatingWordViewModel) {
        self.wordBookService = wordBookService
        _settingsStore = ObservedObject(wrappedValue: settingsStore)
        self.viewModel = viewModel
        _selectedBookForStudy = State(initialValue: settingsStore.selectedBookID)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                NavigationLink("外观", value: 0)
                NavigationLink("词书", value: 1)
                NavigationLink("数据", value: 2)
            }
        } detail: {
            switch selectedTab {
            case 0: appearanceSettings
            case 1: wordBookSettings
            case 2: dataSettings
            default: appearanceSettings
            }
        }
        .frame(width: 520, height: 440)
        .onAppear(perform: loadWordBooks)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    // MARK: - Appearance

    private var appearanceSettings: some View {
        Form {
            Section("外观") {
                LabeledContent("字体大小") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(settingsStore.fontSize) },
                            set: { newValue in settingsStore.fontSize = Int(newValue) }
                        ), in: 10.0...30.0, step: 1.0)
                            .frame(maxWidth: 200)
                        Text("\(settingsStore.fontSize)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                    }
                }
                LabeledContent("窗口透明度") {
                    HStack {
                        Slider(value: $settingsStore.windowOpacity, in: 0.5...1.0, step: 0.05)
                            .frame(maxWidth: 200)
                        Text("\(Int(settingsStore.windowOpacity * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 35)
                    }
                }
            }

            Section("窗口") {
                Toggle("始终置顶", isOn: $settingsStore.alwaysOnTop)
            }
        }
        .padding(16)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Text("按 Esc 退出设置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Word Books

    private var wordBookSettings: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if wordBookEntries.isEmpty {
                Text("暂无词书")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(wordBookEntries, id: \.id) { entry in
                    Button {
                        selectedBookForStudy = entry.id
                    } label: {
                        HStack {
                            Image(systemName: selectedBookForStudy == entry.id ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedBookForStudy == entry.id ? .accentColor : .secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text(entry.name)
                                Text("\(entry.wordCount) 个单词")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }

            Divider()

            Text("支持 CSV、TSV、TXT、JSON")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("导入词书") {
                    showFilePicker = true
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("删除词书") {
                    deleteConfirmShown = true
                }
                .disabled(selectedBookForStudy == nil)
                .buttonStyle(.bordered)
                .alert("删除词书", isPresented: $deleteConfirmShown) {
                    Button("取消", role: .cancel) {}
                    Button("删除", role: .destructive) {
                        performDelete()
                    }
                } message: {
                    let count = selectedBookIDs.count
                    Text("确定删除选中的 \(count) 本词书吗？")
                }

                Button("开始学习") {
                    startStudy()
                }
                .disabled(selectedBookForStudy == nil)
                .buttonStyle(.borderedProminent)
            }

            if let msg = importMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }

            Spacer()

            Divider()
                .padding(.bottom, 4)
            Text("按 Esc 退出设置")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [
            UTType.commaSeparatedText,
            UTType.plainText,
            UTType.json
        ]) { result in
            switch result {
            case .success(let url):
                importFile(url: url)
            case .failure(let error):
                importMessage = "打开文件失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Data

    private var dataSettings: some View {
        Form {
            Section("学习顺序") {
                Picker("顺序", selection: $settingsStore.wordOrderMode) {
                    Text("词书顺序").tag("sequential")
                    Text("随机打乱").tag("random")
                }
                .pickerStyle(.segmented)
            }

            Section("每轮单词数") {
                HStack {
                    Stepper("\(settingsStore.wordsPerRound)",
                            value: $settingsStore.wordsPerRound,
                            in: 1...100)
                    Slider(value: Binding(
                        get: { Double(settingsStore.wordsPerRound) },
                        set: { settingsStore.wordsPerRound = Int($0) }
                    ), in: 1.0...100.0, step: 1)
                        .frame(maxWidth: 200)
                }
            }

            Section("每组轮数") {
                HStack {
                    Stepper("\(settingsStore.roundsPerGroup)",
                            value: $settingsStore.roundsPerGroup,
                            in: 1...20)
                    Slider(value: Binding(
                        get: { Double(settingsStore.roundsPerGroup) },
                        set: { settingsStore.roundsPerGroup = Int($0) }
                    ), in: 1.0...20.0, step: 1)
                        .frame(maxWidth: 200)
                }
            }

            Divider()

            Section("数据管理") {
                Button("导出学习数据") {
                    exportData()
                }
                .buttonStyle(.bordered)
                Button("重置学习记录", role: .destructive) {
                    resetLearningData()
                }
                .buttonStyle(.link)
            }
        }
        .padding(16)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Text("按 Esc 退出设置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Word Book Operations

    private func loadWordBooks() {
        isLoading = true
        Task {
            do {
                let books = try wordBookService.fetchWordBooks()
                wordBookEntries = books.map { book in
                    let words = (try? wordBookService.countWords(in: book.id)) ?? 0
                    return WordBookUIEntry(
                        id: book.id,
                        name: book.name,
                        wordCount: words
                    )
                }
            } catch {
                importMessage = "加载词书失败: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func importFile(url: URL) {
        importMessage = nil
        Task {
            do {
                let name = url.deletingPathExtension().lastPathComponent
                try wordBookService.importFromFile(fileURL: url, bookName: name)
                importMessage = "导入成功"
                loadWordBooks()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    importMessage = nil
                }
            } catch {
                importMessage = "导入失败: \(error.localizedDescription)"
            }
        }
    }

    private func startStudy() {
        guard let bookId = selectedBookForStudy else { return }
        Task {
            do {
                let books = try wordBookService.fetchWordBooks()
                guard books.contains(where: { $0.id == bookId }) else { return }

                // Activate the selected book
                try wordBookService.activateWordBook(id: bookId)
                settingsStore.selectedBookID = bookId

                // Close settings and reload session
                await MainActor.run {
                    viewModel.loadNextWord()
                    dismiss()
                }
            } catch {
                importMessage = "操作失败: \(error.localizedDescription)"
            }
        }
    }

    private func performDelete() {
        Task {
            let idsToDelete = selectedBookIDs
            for id in idsToDelete {
                do {
                    try wordBookService.deleteWordBook(id: id)
                } catch {
                    importMessage = "删除失败: \(error.localizedDescription)"
                    return
                }
            }

            importMessage = "已删除 \(idsToDelete.count) 本词书"
            loadWordBooks()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                importMessage = nil
            }
        }
    }

    // MARK: - Data Operations

    private func exportData() {
        Task {
            do {
                let data = try wordBookService.exportLearningData()
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.json]
                savePanel.nameFieldStringValue = "learning_data.json"

                let result = savePanel.runModal()
                if result == .OK, let url = savePanel.url {
                    try data.write(to: url)
                }
            } catch {
                importMessage = "导出失败: \(error.localizedDescription)"
            }
        }
    }

    private func resetLearningData() {
        Task {
            let confirm = confirmReset()
            if confirm {
                do {
                    try wordBookService.resetLearningData()
                    importMessage = "学习记录已重置"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        importMessage = nil
                    }
                } catch {
                    importMessage = "重置失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func confirmReset() -> Bool {
        let panel = NSAlert()
        panel.messageText = "重置学习记录"
        panel.informativeText = "这将删除所有学习记录和熟练度数据，不可撤销。"
        panel.alertStyle = .warning
        panel.addButton(withTitle: "确认重置")
        panel.addButton(withTitle: "取消")
        let response = panel.runModal()
        return response == .alertFirstButtonReturn
    }

    // MARK: - Helpers

    private var selectedBookIDs: [String] {
        guard let id = selectedBookForStudy else { return [] }
        return [id]
    }

    private var hasSelection: Bool {
        selectedBookForStudy != nil
    }
}

// MARK: - Word Book UI Entry

private struct WordBookUIEntry: Identifiable {
    let id: String
    var name: String
    var wordCount: Int
}
