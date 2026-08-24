import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Settings window content with 3 sections: 外观, 词书, 数据
struct SettingsView: View {
    @State private var selectedTab = 0
    @StateObject private var settingsStore = SettingsStore.shared
    @State private var wordBookEntries: [WordBookEntry] = []
    @State private var showFilePicker = false
    @State private var importMessage: String?

    private let wordBookService = WordBookService(persistence: PersistenceController(isPreview: false))

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
        .frame(width: 500, height: 400)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    NSApp.keyWindow?.close()
                }
            }
        }
        .onAppear(perform: loadWordBooks)
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
                Toggle("开机自动启动", isOn: $settingsStore.launchAtLogin)
            }
        }
        .padding(16)
    }

    // MARK: - Word Books

    private var wordBookSettings: some View {
        VStack(spacing: 12) {
            if wordBookEntries.isEmpty {
                Text("暂无词书")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(wordBookEntries, id: \.id) { book in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(book.name)
                            Text("\(book.wordCount) 个单词")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { book.isEnabled },
                            set: { enabled in
                                Task {
                                    try? wordBookService.toggleWordBook(id: book.id, enabled: enabled)
                                    loadWordBooks()
                                }
                            }
                        ))
                    }
                }
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

                Button("删除词书") {}
                    .disabled(wordBookEntries.filter {!$0.isEnabled}.isEmpty)
            }

            if let msg = importMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
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

    private func loadWordBooks() {
        Task {
            let books = try? wordBookService.fetchWordBooks()
            wordBookEntries = (books ?? []).map { book in
                let words = (try? wordBookService.countWords(in: book.id)) ?? 0
                return WordBookEntry(
                    id: book.id,
                    name: book.name,
                    wordCount: words,
                    isEnabled: book.isEnabled
                )
            }
        }
    }

    private func importFile(url: URL) {
        importMessage = nil
        Task {
            do {
                let name = url.deletingPathExtension().lastPathComponent
                try wordBookService.importFromFile(fileURL: url, bookName: name)
                // Auto-enrich examples in background
                try? wordBookService.enrichExamplesInBackground()
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

    // MARK: - Data

    private var dataSettings: some View {
        Form {
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
    }

    private func exportData() {
        Task {
            do {
                let data = try wordBookService.exportLearningData()
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.json]
                savePanel.nameFieldStringValue = "learning_data.json"

                let result = await savePanel.runModal()
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
            let confirm = await confirmReset()
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

    private func confirmReset() async -> Bool {
        let panel = NSAlert()
        panel.messageText = "重置学习记录"
        panel.informativeText = "这将删除所有学习记录和熟练度数据，不可撤销。"
        panel.alertStyle = .warning
        panel.addButton(withTitle: "确认重置")
        panel.addButton(withTitle: "取消")
        let response = await panel.runModal()
        return response == .alertFirstButtonReturn
    }
}

// MARK: - Word Book Entry

private struct WordBookEntry: Identifiable {
    let id: String
    var name: String
    var wordCount: Int
    var isEnabled: Bool
}
