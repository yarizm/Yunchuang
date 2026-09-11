# 芸窗 Yunchuang - Windows 构建脚本
# 用法: .\build_windows.ps1

$env:CMAKE_TLS_VERIFY = "0"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"

flutter run -d windows
