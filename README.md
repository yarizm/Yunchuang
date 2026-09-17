<div align="center">

<img src="tool/icon.png" width="96" alt="芸窗 Yunchuang" />

# 芸窗 Yunchuang

**离线优先的 EPUB / PDF / TXT 阅读器**

笔记 · 词典 · TTS · 全文搜索 · 防剧透 AI 助手

[![Release](https://img.shields.io/github/v/release/yarizm/Yunchuang)](https://github.com/yarizm/Yunchuang/releases)
[![License](https://img.shields.io/github/license/yarizm/Yunchuang)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows-lightgrey)](https://github.com/yarizm/Yunchuang/releases)

[下载最新版](https://github.com/yarizm/Yunchuang/releases/latest) · [核心功能](#核心功能) · [开发说明](#开发)

</div>

---

> 芸窗是一款本地数据优先的个人阅读器，支持 EPUB、PDF、TXT 阅读，并集成笔记、离线词典、生词本、TTS、全文搜索与 AI 阅读助手。
>
> 除 AI 与翻译功能外，核心阅读功能均可离线使用，书籍、笔记和阅读数据默认保存在本机。

<p align="center">
  <img src="screenshots/shelf.png" width="30%" alt="芸窗书架" />
  <img src="screenshots/reader.png" width="30%" alt="芸窗阅读器" />
  <img src="screenshots/ai-chat.png" width="30%" alt="芸窗 AI 助手" />
</p>

## 核心功能

* **本地优先** —— 书籍、笔记、阅读记录默认保存在本机，不依赖云服务
* **完整阅读体验** —— EPUB / PDF / TXT、排版、搜索、笔记、词典、生词本与 TTS
* **防剧透 AI** —— AI 默认只能访问当前阅读位置之前的内容，限制在工具执行层生效
* **开放模型接入** —— 支持 OpenAI 兼容接口、Claude、Gemini、DeepSeek、Ollama、Dify 等服务
* **跨平台使用** —— 当前支持 Android 与 Windows

> 芸香草能防蠹，古人常用来护书；「芸窗」亦是书斋的雅称。

## 下载

[**前往 Releases 下载最新版**](https://github.com/yarizm/Yunchuang/releases/latest)

| 平台      | 文件                                     | 要求                    |
| ------- | -------------------------------------- | --------------------- |
| Android | `yunchuang-<版本>-android-arm64-v8a.apk` | Android 7.0+，64 位 ARM |
| Windows | `yunchuang-<版本>-windows-x64.zip`       | Windows 10+           |

截图中的示例书目来自 [Project Gutenberg](https://www.gutenberg.org/)，均为公有领域作品；AI 回答使用本地假服务，仅用于展示界面。

---

## 书架

支持自定义书架分组，一本书可属于多个书架，同时支持系列、阅读状态、网格 / 列表视图、排序、封面与元数据编辑。

桌面端可直接将文件或文件夹拖入窗口。

Android 可通过文件管理器「打开方式」或其他应用分享导入。

导入时自动识别 GBK / GB18030 / UTF-16 等编码，TXT 可按中英文章节标题自动分章。

<img src="screenshots/shelf.png" width="280" alt="书架" />

## 阅读

| 格式   | 支持情况                     |
| ---- | ------------------------ |
| EPUB | 可选中文本、划词菜单，按 EPUB 规范读取封面 |
| PDF  | 页面渲染、划词查词、生词本，横屏支持双页     |
| TXT  | 自动分章、自动识别文本编码            |

支持：

* 滚动 / 分页两种阅读模式
* 仿真、滑动、简洁三种分页翻页效果
* 阅读进度精确到章节内位置
* 退出后再次打开自动恢复原阅读位置
* Android 可启用「阅读时横屏」，进入阅读器自动横屏，退出后恢复

<img src="screenshots/reader.png" width="280" alt="阅读器" />

### 目录与跳转

支持目录、书签和跳转历史。

从目录、搜索结果或 AI 引用跳转到其他位置后，可以一键返回上一个阅读位置。

<img src="screenshots/toc.png" width="280" alt="目录与跳转" />

### 排版与纸张

支持调整：

* 字号
* 行高
* 页边距
* 段距
* 字距
* 字体
* 对齐方式
* 段首缩进

排版参数可以设置全局默认值，也可以按书单独覆盖。

正文底色独立于应用全局主题，可选择：

* 白
* 米白
* 杏仁
* 豆绿
* 灰蓝
* 暗灰
* 纯黑
* 自定义颜色

文字颜色会根据背景对比度自动调整。

因此可以单独使用黑底白字阅读，而不需要把整个书架和设置页面切换成暗色主题。

<img src="screenshots/paper.png" width="280" alt="阅读纸张设置" />

### EPUB

EPUB 正文会按照 HTML 的空白处理规则转换为适合阅读的文本：

* 硬换行自动折为空格
* 汉字之间不会错误插入空格
* 脚注链接可点击跳转

对于 Project Gutenberg 一类使用固定宽度硬换行的 EPUB，也能恢复成正常连续排版。

<img src="screenshots/reader-epub.png" width="280" alt="EPUB 阅读" />

## 笔记

支持：

* 划线
* 高亮
* 批注
* 标签分类
* 笔记之间建立关联
* 按书分组
* 按标签筛选

支持从其他平台导入笔记：

* 微信读书 HTML
* Kindle `My Clippings.txt`
* CSV
* JSON

支持导出：

* Markdown
* CSV

<img src="screenshots/notes.png" width="280" alt="笔记" />

## 搜索

芸窗提供统一搜索入口，可同时搜索：

* 书名 / 作者
* 笔记
* 正文全文

搜索结果可以直接跳转到原文位置。

中日韩文本使用子串匹配，正文通过 trigram 索引加速；其他语种使用 SQLite FTS5。

## AI 助手

可以直接在阅读页面向 AI 提问。

AI 助手内置四类工具：

* 搜索当前书籍
* 读取章节摘录
* 搜索笔记
* 读取当前阅读上下文

AI 会根据问题按需调用工具。

回答下方会列出引用来源，点击引用可以直接跳回原文。

内置快捷问法包括：

* 总结本章
* 本章提纲
* 续写本章

也可以创建自定义技能，通过预设指令限制 AI 可以使用哪些工具。

此外支持创建角色人设，并可从书籍内容生成角色，与书中人物进行对话。

AI 会话按书保存，可以随时新建话题重新开始。

<img src="screenshots/ai-chat.png" width="280" alt="AI 助手" />

### 防剧透

**默认开启严格防剧透。**

AI 能访问的书籍内容默认截止到当前阅读位置。

防剧透级别可以全局设置，也可以按书单独覆盖。

| 档位        | 行为               |
| --------- | ---------------- |
| 严格防剧透（默认） | 只能检索当前阅读位置之前的内容  |
| 访问前询问     | 需要访问未读内容时先请求本次授权 |
| 允许全书      | 可以检索后续章节         |

限制在本地工具执行层生效。

越过已读边界的章节不会进入模型上下文，而不是单纯依赖提示词约束 AI。

<img src="screenshots/ai-safety.png" width="280" alt="AI 防剧透设置" />

### AI 服务商

支持：

* OpenAI 兼容接口
* Ollama
* Dify

同时内置常见服务商模板：

* OpenAI
* Claude
* Gemini
* DeepSeek
* 通义千问
* Kimi
* 智谱
* 硅基流动
* OpenRouter
* Ollama
* Dify

选择模板后，接口地址和模型信息会自动填充，只需要配置 API Key。

模型名称还可以直接从服务端拉取列表进行选择，不需要手动查阅文档填写。

API Key 只保存在本机，应用备份不会包含密钥。

<img src="screenshots/ai-provider.png" width="280" alt="AI 服务商配置" />

### Token 用量

芸窗可以按 Provider 记录 AI Token 用量：

* 今日用量
* 累计用量
* 输入 Token
* 输出 Token
* 最近 7 / 14 / 30 天趋势

支持折线图和柱状图。

如果服务端返回标准 `usage` 数据，则记录准确值；如果没有返回，则根据文本长度估算并进行标记。

芸窗只负责统计 Token 数量，不自动换算费用，因为不同服务商和模型的价格不同。

<img src="screenshots/ai-usage.png" width="280" alt="AI Token 用量统计" />

## 词典、生词本与翻译

### 离线词典

支持导入 StarDict 离线词典。

划词后即可查询，多本词典可以同时启用。

### 生词本

生词会记录来源书籍和原文位置，可以随时返回对应原文。

### 翻译

划选文本后可主动调用翻译。

翻译内容会发送给当前配置的默认 AI Provider，仅在用户主动点击翻译时发送。

## TTS

支持文本朗读：

* 断点续播
* 独立语速调节
* 朗读计时
* 迷你播放器
* 全屏控制面板

Android 端接入系统媒体会话，可以：

* 后台播放
* 在通知栏控制播放状态

## 阅读统计

支持查看：

* 今日阅读时长
* 本周阅读时长
* 本月阅读时长
* 累计阅读时长
* 连续阅读天数
* 单书阅读时长排行
* 年度阅读热力图

<img src="screenshots/stats.png" width="280" alt="阅读统计" />

## 备份

支持一键导出完整 ZIP 备份，包括：

* 数据库
* 书籍文件
* 封面
* 应用偏好
* 自定义背景图

可以从 ZIP 完整恢复。

同时支持上传备份到自己的 WebDAV 网盘，并设置：

* 每天自动上传
* 每周自动上传

备份中不会包含：

* AI API Key
* WebDAV 凭据

Android 系统自动备份已关闭，因此本地书库不会被自动同步到 Google Drive。

## 外观

支持以下全局主题：

* Light
* Sepia
* Dark
* 跟随系统

全局背景可以选择：

* 纯色
* 主题色渐变
* 内置插画
* 自定义图片

背景浓度可以调节，并会应用到书架、设置页和阅读页。

<img src="screenshots/reader-dark.png" width="280" alt="暗色阅读界面" />

## 当前限制

| 项目 | 限制                                          |
| -- | ------------------------------------------- |
| 平台 | 当前仅支持 Android 和 Windows                     |
| 格式 | 暂不支持 MOBI / AZW3 / FB2                      |
| 同步 | WebDAV 当前用于完整备份包上传 / 下载，恢复会整体覆盖本机数据，不进行多端合并 |
| 排版 | 暂未实现中文标点挤压与禁则，正文默认左对齐                       |

即使不配置任何 AI Provider，也可以使用除 AI 和翻译之外的全部功能。

## 开发

### 环境

| 层    | 技术                      |
| ---- | ----------------------- |
| 框架   | Flutter 3.x（Dart ≥ 3.4） |
| 状态管理 | Riverpod 2.x            |
| 路由   | GoRouter                |
| 数据库  | Drift + SQLite + FTS5   |
| 测试   | flutter_test + mocktail |

项目包含 100+ 个测试文件。

### 本地运行

```bash
flutter pub get
flutter run -d android
```

Windows：

```bash
flutter run -d windows
```

生成的 `*.g.dart` 已随仓库提交，因此克隆项目后不需要先运行 `build_runner`。

修改以下目录中的 Drift 定义后，需要重新生成：

```text
lib/database/tables/
lib/database/daos/
```

运行：

```bash
dart run build_runner build
```

### Android Release 签名

复制：

```text
android/key.properties.example
```

为：

```text
android/key.properties
```

填写 keystore 信息后执行：

```bash
flutter build apk --release
```

### 独立测试数据目录

可以通过环境变量：

```text
YUNCHUANG_DATA_DIR
```

指定独立的数据目录。

数据库、书籍和封面都会写入该位置，适合：

* 测试新版本
* 调试
* 自动化测试
* 截图

不会影响真实书库。

## 项目结构

```text
lib/
├── main.dart / app.dart    # 应用入口与底部导航
├── database/               # Drift 表定义与 DAO
├── models/                 # 领域模型
├── providers/              # Riverpod Provider
│   └── ai/                 # AI Provider、Agent、防剧透边界
├── services/               # 书籍 / 笔记 / 搜索 / TTS / 备份 / 词典 / 翻译 / 生词
├── parsers/                # 书籍解析器与笔记导入器
├── typography/             # 分页排版内核
├── pages/                  # 页面
├── widgets/                # 共享组件
├── theme/                  # 主题与自定义路由
└── utils/                  # 断句、编码检测等工具
```

## License

本项目基于 [MIT License](LICENSE) 开源。
