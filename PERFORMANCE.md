# Android 性能回归

性能数据必须来自真机 Profile 构建。Debug APK 不能用于判断流畅度、发热或启动耗时。

## 固定场景

使用同一台设备和同一组 TXT、EPUB、PDF 测试书，各执行三次：

1. 强制停止应用后，点击书籍直到出现第一段正文。
2. 关闭 TTS，连续滚动正文 30 秒。
3. 连续执行基础翻页和仿真翻页各 30 秒。
4. 开启 TTS，连续阅读 30 秒，观察句子高亮和自动跨章。
5. 打开包含至少 5000 章的目录，快速往返滑动 30 秒。
6. 拖动目录全书进度滑杆跳到远处章节，再切换章节并立即打开 AI 面板，确认目标章先显示、邻章预热不阻塞交互。
7. 连续执行目录、搜索、笔记和 AI 来源跳转，再逐步后退和前进。

代码侧基线使用固定 Widget 测试，覆盖虚拟列表、长段落切块、分页与仿真翻页、
TTS 跨页高亮和目录大数据量：

```powershell
flutter test test/pages/reader_performance_test.dart
```

代码会在 Flutter Timeline 中记录：

- `book_open`
- `book_open_start`
- `file_read`
- `chapter_index`
- `chapter_decode`
- `page_render`
- `first_readable_frame`
- `html_to_spans`
- `reader_toc_open`
- `reader_toc_first_frame`

同时会向 `reader.performance` 日志输出首段正文耗时。

## 运行

```powershell
flutter run --profile -d <device-id>
```

在 DevTools Performance 中分别录制打开书和滚动场景。快速帧统计可以使用：

```powershell
adb shell dumpsys gfxinfo com.yarizm.yunchuang reset
# 在手机上完成一次固定场景
adb shell dumpsys gfxinfo com.yarizm.yunchuang framestats > gfxinfo.txt
```

需要 CPU 调用栈时，改装 Debug APK 后使用 Android Studio CPU Profiler 或
Simpleperf。每份报告必须注明设备、Android 版本、构建模式、书籍大小和运行次数。

仓库提供了统一采集脚本。开始固定场景前重置统计：

```powershell
.\tool\android_performance.ps1 -Action reset -DeviceId <device-id>
```

完成一次固定场景后导出带设备信息的报告：

```powershell
.\tool\android_performance.ps1 -Action capture -DeviceId <device-id>
```

报告默认写入 `performance-results/`，该目录只保存本地测试数据，不提交正文、
设备隐私数据或临时 trace。

## 发布门槛

- 热打开到首段正文低于 500ms，冷打开低于 1.5s。
- 5000 章目录打开到首帧低于 300ms。
- 静止阅读时 CPU 使用率应快速回落。
- 60Hz 设备连续滚动时不得持续出现超过 16ms 的 UI 或 Raster 帧。
- 120Hz 设备正文滚动和基础翻页以 8.3ms 帧预算为目标。
- TTS 自动跨章不得重复句子、闪现工具栏或出现明显停顿。
- 修复前后必须使用相同设备、书籍和操作路径，保留原始 trace。

## 设备矩阵

- REDMI K50U：120Hz 正文、翻页、目录和来源跳转。
- OnePlus ACE2：120Hz 正文滚动、TTS 高亮和章节切换。
- 中低端 Android：60Hz 最低流畅度与内存基线。
- Windows：功能、数据库和自动化测试兼容性。

只有真机 Profile 数据可以关闭性能验收；Widget 测试通过只代表代码侧
没有退回到全量构建或超大文本块渲染。
