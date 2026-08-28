# MiniVocab 更新日志

## [0.1.0] — 2026-08-28

### 已修复

**1. 始终置顶不生效**
- 将 `WindowGroup` 创建的 `NSWindow` 的 `styleMask` 从 `.borderless` 改为 `[.titled, .closable, .resizable, .fullSizeContentView]`
- 设置 `titleVisibility = .hidden` 和 `titlebarAppearsTransparent = true`，保持视觉简洁
- `window.level = .floating` 现在正确使窗口位于普通应用之上
- 添加 `canJoinAllSpaces` 窗口集合行为，支持桌面空间切换
- 窗口仅悬浮于其他窗口之上，不会抢夺焦点

**2. 设置窗口无法关闭**
- 移除了 macOS 原生 `Settings` scene
- 设置窗口改为主窗口的 `.sheet` 弹出
- 移除了无效的「完成」按钮
- 添加 `onKeyPress(.escape)` 正确关闭设置窗口
- 设置底部新增「按 Esc 退出设置」提示

**3. 字体大小和透明度修改后悬浮窗口无变化**
- 之前每个 View 和窗口各自创建了独立的 `SettingsStore` 实例，设置保存到了一个实例，UI 读取的是另一个
- 在 `MiniVocabApp` 中统一使用 `SettingsStore.shared`，注入到 `FloatingWordView`、`SettingsView` 和窗口配置器
- `FloatingWordView` 直接读取 `settingsStore.fontSize` 和 `settingsStore.windowOpacity`，实时刷新
- 字体大小控制英文单词主字体；例句和中文释义按比例缩放（0.6 倍和 0.65 倍）
- 透明度通过 `NSWindow.alphaValue` 直接设置窗口属性，而非仅修改 SwiftUI 的 `.opacity()`

**4. 导入词书后悬浮窗口没有单词**
- `WordBook.words` 关系在导入时未被建立：单词虽然存入了数据库，但没有关联到词书
- 在 `WordBookService.importFromFile()` 中添加 `wordBook.words.append(word)`
- `StudySessionManager.nextWord()` 现在正确从已启用的词书中获取单词
- 「开始学习」按钮会启用选中的词书，重建学习 session，然后关闭设置窗口

**5. 删除词书按钮无效**
- 将空实现 `Button("删除词书") {}` 替换为完整功能
- 词书列表改为点击行切换选中状态（复选框样式）
- 删除前有确认弹窗
- `deleteWordBook()` 从 SwiftData 中删除词书
- 清理关联的 `LearningState` 和 `ReviewRecord` 数据
- 如果被删除的是当前正在学习的词书，悬浮窗口显示「请先选择词书」
- 删除后 UI 立即刷新

**6. 悬浮窗口无法调整大小**
- `.borderless` 样式移除了原生的边框调整区域
- 新样式 `[.titled, .closable, .resizable, .fullSizeContentView]` 恢复 macOS 原生边缘和角落调整
- `isMovableByWindowBackground = true` 处理窗口拖拽，避免自定义 `DragGesture` 与 resize 冲突
- 最小尺寸设为 150x150，防止窗口缩到界面错乱
- 窗口位置和大小保存到 `UserDefaults`，重启后恢复

### 架构调整

- **统一数据源**: `SettingsStore.shared` 在 `MiniVocabApp` 中创建一次，全部分享
- **学习流程**: 导入 → 选择词书 → 「开始学习」→ 启用词书 → 通知 → `StudySessionManager` 重建学习池 → `FloatingWordView` 显示单词
- **设置窗口**: 原生 Settings scene 替换为 `.sheet`，生命周期更可靠

### 修改文件

| 文件 | 改动 |
|------|------|
| `MiniVocabApp.swift` | 单一 SettingsStore，sheet 方式展示设置，移除 Settings scene |
| `FloatingWindowController.swift` | 可调整大小样式，窗口frame持久化，level 管理 |
| `FloatingWordView.swift` | 观察共享 SettingsStore，字体/透明度动态绑定 |
| `SettingsView.swift` | 词书选择、导入、删除、开始学习、Esc 关闭 |
| `FloatingWordViewModel.swift` | 监听 `studySessionReload` 通知重建学习池 |
| `StudySessionManager.swift` | 清理无用代码 |
| `WordBookService.swift` | 建立 WordBook.words 关联，完善删除级联清理 |
