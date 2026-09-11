# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

芸窗（Yunchuang）——不剧透的 AI 阅读器，Flutter 应用，支持 EPUB/PDF/TXT 阅读、笔记管理、AI 对话、TTS 朗读、词典查询、生词本、翻译。仅支持 Android、Windows 两端。

## 常用命令

```powershell
# 安装依赖
flutter pub get

# 代码生成（修改 database tables 或 DAO 后必须运行）
dart run build_runner build

# Windows 运行
.\build_windows.ps1

# Android 运行
flutter run -d android

# 静态分析
flutter analyze

# 运行测试
flutter test
```

## 架构分层

```
UI (Pages/Widgets)
  ↓
State (Riverpod providers)
  ↓
Business Logic (Services)
  ↓
Data Access (Drift DAOs)
  ↓
Database (SQLite via Drift ORM + FTS5 全文搜索)
```

**Services**：`BookService`、`NoteService`、`SearchService`、`TtsService`、`BackupService`、`WebDavService`、`DictionaryService`、`TranslationService`、`VocabularyService`、`ScreenBrightnessService`

**DAOs**：`BookDao`、`NoteDao`、`ProgressDao`、`AiDao`、`CollectionDao`、`DictionaryDao`、`VocabularyDao`、`BookTtsSettingsDao`、`BookReadingSettingsDao`

## 阅读器架构（重点）

`ReaderPage`（`ConsumerStatefulWidget`）是阅读器入口，组合多个部件：

- `ReaderController`（`ChangeNotifier`，非 Riverpod provider）— 阅读器中心状态：当前章节索引、滚动位置、阅读时长计时器、TTS 高亮句索引。`bookProgress` getter 综合章节索引与章内滚动比例，供书架进度条与持久化百分比共用。
  - **性能设计**：滚动位置额外通过 `scrollPositionListenable`（`ValueNotifier`）暴露，高频滚动更新走 ValueNotifier 而非 `notifyListeners()`，避免大范围重建。改动此处需同步检查 `test/pages/reader_performance_test.dart`。
- `FormatReader` 抽象 + `ReadingMode` 枚举（`scroll` / `page`）— 两种阅读模式。`paged_reader.dart` 实现分页渲染，`paragraph_layout.dart` 负责段落排版计算。
- 三个格式 Reader：`txt_reader`、`epub_reader`（flutter_html）、`pdf_reader`（SyncfusionPdfViewer，用 `GlobalKey<PdfReaderState>` 暴露跳页 API）。
- `ImmersiveReaderShell`、`ReaderToolbar`、`QuickSettingsPanel`、`TtsControlPanel` — 沉浸式 UI 层，通过 `GlassPageRoute` 推入。
- `ReaderNavigationHistory` — 章节跳转历史，支持返回上一个阅读位置。
- `reader_data_loader.dart` / `reader_overlays.dart` / `reader_toc_sheet.dart` — 从 `reader_page.dart` 拆出的数据加载、浮层、目录。

阅读进度持久化由 `ProgressDao` 负责，章节切换、滚动防抖、退出时保存位置等逻辑在 `reader_page.dart` 中协调。

## 路由设计

GoRouter + `StatefulShellRoute.indexedStack` 管理四个底部 Tab：Shelf(`/`)、Notes(`/notes`)、Stats(`/stats`)、Settings(`/settings`)。

子页面（阅读器、搜索、AI 对话、设置详情页）不走 GoRouter 路由表，而是通过 `Navigator.of(context, rootNavigator: true).push(GlassPageRoute(...))` 命令式推入。`GlassPageRoute` 是自定义 `PageRoute`，`opaque: false` 以透出背景动画。

## 状态管理

使用 Riverpod 2.x（`flutter_riverpod`）。主要 provider：

- `booksProvider` (`AsyncNotifierProvider`) — 书籍列表 + 导入/删除操作
- `preferencesProvider` (`NotifierProvider`) — 全局阅读偏好（字体大小、行高、主题、屏幕方向）
- `bookReadingSettingsProvider` — 按书籍覆盖的阅读设置
- `ttsServiceProvider` (`ChangeNotifierProvider`) — TTS 引擎单例
- `allNotesProvider` / `allTagsProvider` (`FutureProvider`) — 全局笔记和标签
- `notesForBookProvider` (`FutureProvider.family`) — 按书籍筛选笔记
- `translationProvider`、`spoilerProtectionProvider`、`readingStatsProvider`

Provider 覆盖链：`main()` 中通过 `overrideWithValue` 注入 `SharedPreferences`、`TtsMediaSession`、`AiPersonaSelectionStore`。

## 启动流程

`main()` 顺序敏感：
1. `BackupService.applyPendingRestore()` — 必须在数据库打开前执行，失败时显示 `_StartupFailureApp` 而非崩溃
2. `SharedPreferences.getInstance()`
3. Android 平台初始化 `AudioService`（TTS 媒体会话通知），失败仅记日志不阻断启动

## 数据库

Drift ORM（`drift` + `sqlite3_flutter_libs`），数据库文件 `reading_offline.db` 在应用文档目录（**沿用旧名，不随项目更名**，理由见 `BackupService._databaseName` 注释）。**当前 `schemaVersion = 20`**。

**21 张实体表**：

| 分组 | 表 |
|------|-----|
| 书籍 | `books`、`chapters`、`reading_progress`、`reading_sessions`、`book_collections`、`book_collection_items` |
| 按书设置 | `book_tts_settings`、`book_reading_settings` |
| 笔记 | `notes`、`tags`、`note_tags`、`note_relations` |
| AI | `ai_providers`、`ai_conversations`、`ai_messages`、`ai_skills`、`ai_personas` |
| 词典/生词 | `dictionary_sources`、`dictionary_entries`、`dictionary_aliases`、`vocabulary_entries` |

**4 张 FTS5 虚拟表**：`books_fts`（title, author, description）、`notes_fts`（selected_text, content）、`chapters_fts`（content，即正文）、`chapters_trigram`（content，`tokenize='trigram'`）。均使用 external content 模式，每张表 3 个触发器、共 12 个同步。FTS5 表无法在 `@DriftDatabase` 中声明，由 `createFtsTables()` 用 `customStatement` 手动创建；trigram 那张另有 `createChaptersTrigram()` 单独建，迁移时只补它——顺手重建其他 FTS 表会在 v4 之前的老库上炸（那时 `chapters` 还没有 `content` 列）。

**搜索有两条后端，`SearchService` 按查询语种路由**：FTS5 的默认 `unicode61` 分词器把连续的汉字 / 假名 / 谚文当作**一个 token**，`MATCH "计算机"` 永远匹配不到《深入理解计算机系统》——这不是查询写法问题，改 MATCH 表达式无解。因此 `SearchPlan.forQuery()` 检测到这些文字时改走 `AppDatabase.searchBooksLike/searchNotesLike/searchChaptersLike`（`LIKE '%q%'`），空格分词的语种仍走带索引、bm25 排序的 FTS 路径。

正文搜索在 LIKE 之外还有一层 `chapters_trigram` 前置过滤：trigram 分词器按三字滑窗建索引，能把子串搜索变成索引查找。它只收窄候选集，最终判定仍由 LIKE 负责，所以分词器的边界行为不影响结果正确性。**三字以下的查询用不了它**（trigram 要三个字符起），两字中文词只能退回全表扫描——这个短板消不掉。实测 3000 章规模下 26ms → 4ms，代价是正文部分 +67% 体积。改搜索相关代码时必须跑 `test/services/search_service_test.dart`，其中的中文用例就是为这个坑设的。

表定义在 `lib/database/tables/`，DAO 在 `lib/database/daos/`，**修改后必须运行 `dart run build_runner build`** 重新生成 `.g.dart`。

**迁移约定**：`onUpgrade` 中每步用 `if (from < N)` 判断，涉及建表时配合 `_tableExists()` 检查，保证幂等。

**删书会让库变大，必须显式压缩**。FTS5 外部内容表删行时不是就地移除，而是往索引里**追加**一条删除标记。实测一本 1500 章、300 万字的书，删掉之后库从 57MB 涨到 90MB 且不会自己缩回去；加了 `chapters_trigram` 之后更严重（trigram 条目数是普通 FTS 的三倍）。`AppDatabase.compact()` 先对四张 FTS 表跑 `optimize` 再 `VACUUM`——**两步缺一不可**：只 VACUUM 只降到 88MB（删除标记是活数据），只 optimize 还是 90MB（腾出的页不还给系统），两步一起才回到 0.34MB。开销 695ms + 22ms，几乎全在 optimize，且跟索引规模走而不是跟删了多少走，所以 `BookService` 用 50 万字的门槛决定要不要跑。见 `test/database/compaction_test.dart`。

## 数据目录

数据库、书籍、封面、词典、背景图都放在 `appDataDirectory()`（`utils/app_data_directory.dart`）返回的目录下，默认是系统文档目录。设了环境变量 `YUNCHUANG_DATA_DIR` 就用它——README 的截图就是这样在一个空目录 + Gutenberg 公版书上截的，没有碰真实书库。不要在各处直接调 `getApplicationDocumentsDirectory()`，新代码走这个函数（或各 Service 的 `appDirectoryProvider` 注入）。

## 支持的格式

| 类型 | 格式 | 解析器 | 阅读器 Widget |
|------|------|--------|--------------|
| 书籍 | TXT | `parsers/txt_parser.dart` | `txt_reader.dart` |
| 书籍 | EPUB | `parsers/epub_parser.dart` (epubx) | `epub_reader.dart` (flutter_html) |
| 书籍 | PDF | `parsers/pdf_parser.dart` (syncfusion) | `pdf_reader.dart` (syncfusion) |
| 笔记导入 | 微信读书 HTML | `parsers/weread_importer.dart` | — |
| 笔记导入 | Kindle Clippings | `parsers/kindle_importer.dart` | — |
| 笔记导入 | CSV | `parsers/csv_importer.dart` | — |
| 笔记导入 | JSON | `parsers/json_importer.dart` | — |
| 词典 | StarDict | `services/stardict_parser.dart` | `pages/settings/dictionary_page.dart` |

所有笔记导入器输出统一的 `ImportedNote` 模型。

**EPUB 正文转文本**（`models/html_text_document.dart`）按 HTML 的空白规则走：源码里的换行折成一个空格，两边都是汉字时连空格也不要（浏览器的段落分隔符规则），只有 `<pre>` 里的换行才保留；段落边界只认 `<p>`/`<br>`/块级元素。Gutenberg 一类 EPUB 的 XHTML 按固定宽度硬换行，之前把换行当换行，每一行都成了一段。

**EPUB 封面**按规范找：EPUB3 的 `properties="cover-image"`、EPUB2 的 `<meta name="cover">` 指向的 manifest 项，都没有再退到文件名带 cover 的图（`EpubParser.findCoverBytes`）。之前依赖 epubx 的 `CoverImage`，它只认 EPUB2 且要把图解码一遍，而且拿到之后取的是 `Images` 里的第一张——插图本的封面会变成随便哪张插图。

## AI 集成

### Provider 层

三个 AI Provider 实现共同的抽象类（`ai_provider.dart`），配置存储在 `ai_providers` 表：

- `OpenAIProvider` — `/chat/completions`，支持 SSE 流式
- `OllamaProvider` — `/api/chat`，支持流式 + `/api/tags` 健康检查
- `DifyProvider` — `/chat-messages`，支持流式

`AIService` 作为工厂类，从数据库读取默认 provider 配置并实例化。

### Agent 层

`AIAgentService` 实现带工具调用的 agent loop（**非简单问答**）：

- **工具**（`agent_tools.dart`）：`SearchCurrentBookTool`、`ReadChapterExcerptTool`、`SearchNotesTool`、`GetCurrentReadingContextTool`
- **循环上限**：`maxToolCalls = 3`、`maxInvalidJson = 2`
- **字符预算**：`maxRequestChars = 80000`，用户 prompt 预算按 `min(48000, max(4000, 80000 - baseChars))` 动态计算；超限时保留开头/中段/结尾并通过 `AgentEvent.status` 告知用户
- **Skills**（`ai_skills` 表）：通过 `allowedToolsJson` 白名单限制单个 Skill 可用的工具；白名单非法时禁用本轮工具调用并提示
- **Personas**（`ai_personas` 表）：角色人设注入 system prompt，支持从书籍内容生成角色，生成过程可中断并通过 `CharacterPersonaCheckpointStore` 断点续做
- **剧透保护**（`spoiler_protection_provider.dart`）：限制 AI 读取当前阅读进度之后的内容，可按书覆盖全局设置

UI 在 `widgets/ai_chat_panel.dart`（阅读器内嵌）和 `pages/ai/ai_chat_page.dart`。

## 主题与背景

`lib/theme/app_theme.dart` 定义 Light / Sepia / Dark 三套 Material 3 主题，`app.dart` 的 `_resolveTheme` 支持 `system` 跟随系统亮度（sepia 不参与跟随）。全局使用毛玻璃卡片（`GlassContainer`，`BackdropFilter` + `ClipRRect`）。

**全局背景**（`widgets/app_background.dart` 的 `AppBackground`）**必须挂在 `MaterialApp.builder` 里，不能包在 `MaterialApp` 外面**。包在外面就取不到 `Theme.of(context)`，颜色只能写死——这正是之前的样子：深棕底 `#2C2118` + 粉蓝渐变 + 水彩插画常驻，三套主题下一模一样，日间主题于是成了「暖白顶栏压在深棕插画上」，书架网格区更是整片露出插画。现在底色一律取 `colorScheme.surface`，装饰层只是叠加。

四种样式（`models/reading_background.dart` 的 `AppBackgroundStyle`）：`solid` / `gradient`（由主题强调色推出）/ `illustration`（内置 `assets/home_bg.png`）/ `custom`（用户自选图）。浓度由 `backgroundIntensity` 控制，`0` 等价于纯色且完全不建装饰层。`backgroundAnimationEnabledProvider` 只管渐变的流动动画，阅读时会被关掉。

自定义背景图由 `services/background_image_service.dart` 管理：长边缩到 2160px，落在应用目录的 `backgrounds/` 下。**偏好里只存文件名，不存绝对路径**——文档目录的绝对路径在重装、换设备、恢复备份后都会变。目录随备份一起导出（`backupFormatVersion` 因此升到 4），和 `preferences.json` 里的文件名重新对上。

设置界面的预览统一走 `reader_theme.dart` 的 `readerPreviewColors`，主题解析统一走 `AppTheme.resolve`。此前「阅读偏好」页和阅读器快捷设置各写死了一组预览色（sepia `#F5F0E1`、dark `#1E1E1E`），和三套主题真正的 surface（`#FFFBF0`、`#2D2D2D`）对不上——预览显示的从来就不是实际读到的颜色。新增预览时用这两个函数，不要再写第三份。

**正文纸张**（`ReaderPaper` + `theme/reader_theme.dart` 的 `readerThemeFor`）独立于全局主题：想黑底白字读书，不必把书架和设置页一起变暗。实现方式是给阅读器子树套一层 `Theme`，覆盖 `colorScheme` 的 surface 家族与 `textTheme`——阅读器上下几十个部件都从这两处取色，覆盖来源比给每个部件加参数省事，工具栏和目录面板也会自动跟着换。自定义底色只让用户选底色，字色由 `ReaderPaper.foregroundFor` 按对比度推，保证 WCAG AA；`textTheme` 必须一起覆盖，因为 `AppTheme` 是用 `.apply(bodyColor:)` 把字色写死进去的。

## 测试

105 个测试文件，覆盖 database / models / pages / parsers / providers / services / widgets。提交前应确保 `flutter analyze` 无告警、`flutter test` 全绿。

性能相关测试（`reader_performance_test.dart`、`home_shelf_performance_test.dart`）约束重建次数，修改阅读器或书架渲染逻辑时容易触发失败，需认真对待而非直接调整阈值。另见 `PERFORMANCE.md`。

## AI 面板的拆分

`widgets/ai_chat_panel.dart` 原本 2600 行，已经拆出 `widgets/ai_chat/`：

| 文件 | 内容 |
|------|------|
| `agent_source_parsing.dart` | 把工具回传的 JSON 解析成来源引用。纯函数，输入是模型给的自由格式 Map，缺字段、类型不对都要兜住 |
| `attachment_viewer.dart` | 附件全文弹层 + 分块。分块要避开代理对，切在中间会把 emoji 拆成乱码 |
| `chat_message.dart` | `ChatMsg`：历史裁剪、重试、未落库标记都挂在它身上 |
| `source_reference_list.dart` | 回复下方的来源卡片，只吃一组引用和点击回调 |
| `character_name_dialog.dart` | 生成角色人设前问角色名 |
| `ai_markdown_style.dart` | 回复的 Markdown 样式 |

拆出去的都是**不碰面板状态**的部分，因此各自有独立测试（`test/widgets/agent_source_parsing_test.dart`、`attachment_chunking_test.dart`）。面板剩下的是状态机本身：发送循环、会话切换、人设管理、消息持久化——这些缠在 `setState` 和请求 id 上，再拆要先把状态拎出来，不是搬代码能解决的。

新增 AI 功能时：无状态的部分放 `ai_chat/` 并配测试，别再堆回面板。

## 大文件提醒

以下文件已超过合理体积，新增功能时优先考虑拆分而非继续堆积：

- `widgets/ai_chat_panel.dart`（~1970 行，已拆出上表六个文件）
- `pages/reader/reader_page.dart`（~2200 行）
- `pages/reader/paged_reader.dart`（~1200 行）
