# third_party

放进仓库的第三方依赖，由 `pubspec.yaml` 引用。构建时不再联网下载它们。

## flutter_tts（4.2.5 + 补丁）

`pubspec.yaml` 的 `dependency_overrides` 指向这里。

原版的 Windows 实现在注册插件时就创建系统语音对象。注册发生在应用启动、第一帧之前。系统语音运行时出问题时，创建会抛异常（见过 `0x800455A0 Internal Speech Error`）。异常没有被接住，整个应用会直接退出：朗读用不了，阅读器也打不开。4.2.5 是 pub 上的最新版，没有修这个问题。

除了没带 `example/`，其余文件都与 pub 上的 4.2.5 相同。只改了 `windows/flutter_tts_plugin.cpp`，改动处标了 `[yunchuang]`：

- **语音对象建不起来时**：记下原因，应用照常启动；之后每次调用都会重试，仍失败就返回 `tts_unavailable` 错误。`TTSService` 收到这个错误后，提示改用外部语音服务。
- **方法调用中抛出 WinRT 异常时**：改为返回 `tts_error` 给 Dart，进程不再退出。
- **合成失败时**：发出 `speak.onError`。原版既不出声也不回调，Dart 端会一直等。
- **还没朗读过就调用 `stop()` 时**：如果开着 `awaitSpeakCompletion`，原版会解引用空指针。
- **`setLanguage`**：原版对任何语言都返回成功，因为 `found = true` 在循环里每次都执行。

升级 flutter_tts 时，先看新版本的 `windows/flutter_tts_plugin.cpp` 有没有修掉这些问题：

- 修了：删掉这个目录和对应的 override。
- 没修：用新版本的文件替换这里，再把上面几处改回去。

## sqlite3（预编译库）

drift 依赖的 `sqlite3` 包带有构建钩子，`flutter build`、`flutter run` 和 `flutter test` 都会运行它。钩子默认从 GitHub Release 下载预编译的 SQLite，下载地址写死在钩子里，无法换成镜像。GitHub 的下载域名 `release-assets.githubusercontent.com` 在这边时常连不上，一旦连不上，构建就会失败。

`pubspec.yaml` 的 `hooks.user_defines` 让钩子改为读这个目录。钩子会按 `sqlite3` 包里记录的 SHA-256 校验文件，对不上就报错，所以这里的文件与 GitHub Release 上的完全相同。这个选项在钩子里叫 `test-sqlite3`：它本来是包作者测试用的，作用是从本地目录读取同名文件。升级时要确认这个选项还在。

目录里只放了这个项目用得到的库：

- Windows x64
- Android arm、arm64、x64
- Linux x64（CI 在 Linux 上跑 `flutter test` 时使用）

**升级 sqlite3 包之后**（drift 升级时常会带着它一起升），构建会报 `Hash of downloaded file ... expected ...`。这时运行：

```powershell
.\tool\fetch_sqlite3.ps1
```

脚本会按新版本的哈希表重新下载。GitHub 连不上时，它会依次改用 ghfast.top、gh-proxy.com、ghproxy.net 这几个镜像，每个下载下来的文件都要先通过哈希校验。下载完成后，提交这个目录。镜像失效时，直接修改脚本里的列表。
