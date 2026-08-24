import SwiftUI

/// Preview for field mapping and word count before importing
struct ImportPreviewView: View {
    let importedWords: [ImportedWord]
    let fieldMapping: FieldMapping
    @State private var confirmed = false

    var body: some View {
        VStack(spacing: 16) {
            Text("导入预览")
                .font(.headline)

            Text("检测到 \(importedWords.count) 个单词")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Field mapping UI
            Form {
                Section("字段映射") {
                    LabeledContent("单词字段") {
                        Picker("", selection: .constant(FieldColumn.word)) {
                            Text(FieldColumn.word.displayName).tag(FieldColumn.word)
                            Text(FieldColumn.english.displayName).tag(FieldColumn.english)
                        }
                    }
                    LabeledContent("释义字段") {
                        Picker("", selection: .constant(FieldColumn.meaning)) {
                            Text(FieldColumn.meaning.displayName).tag(FieldColumn.meaning)
                            Text(FieldColumn.definition.displayName).tag(FieldColumn.definition)
                            Text(FieldColumn.translation.displayName).tag(FieldColumn.translation)
                        }
                    }
                    LabeledContent("音标字段") {
                        Picker("", selection: .constant(FieldColumn.phonetic)) {
                            Text(FieldColumn.phonetic.displayName).tag(FieldColumn.phonetic)
                            Text(FieldColumn.unknown.displayName).tag(FieldColumn.unknown)
                        }
                    }
                }
            }

            // Preview
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(importedWords.prefix(10)), id: \.word) { w in
                        HStack {
                            Text(w.word)
                                .fontWeight(.medium)
                            if let meaning = w.meaning {
                                Text(meaning)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.system(size: 12))
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            )

            Divider()

            HStack {
                Spacer()
                Button("取消") { confirmed = false }
                Button("确认导入") { confirmed = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 450, height: 500)
    }
}

struct FieldMapping {
    let wordColumn: FieldColumn
    let meaningColumn: FieldColumn
    let phoneticColumn: FieldColumn?
    let exampleColumn: FieldColumn?
}
