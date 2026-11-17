# 把 sqlite3 包构建钩子要用的预编译库下载到 third_party/sqlite3/。
#
# 构建时钩子直接读这个目录（pubspec.yaml 的 hooks.user_defines），不再去 GitHub
# 下载。sqlite3 的版本在 pubspec.yaml 里钉死了；改了那个版本号、跑过
# flutter pub get 之后，跑一遍这个脚本，把新文件和版本号一起提交。
#
# 先试 GitHub 直连，连不上再依次试镜像。不管从哪下载，都按 sqlite3 包里记录的
# SHA-256 校验，对不上就换下一个源；构建钩子拿到文件后还会再校验一遍。
#
# 用法: .\tool\fetch_sqlite3.ps1

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# 本项目构建用得到的几份：Windows x64、Android 的三种 ABI，以及 CI 在 Linux 上
# 跑 flutter test 用的 x64。
$files = @(
  'sqlite3.x64.windows.dll',
  'libsqlite3.arm.android.so',
  'libsqlite3.arm64.android.so',
  'libsqlite3.x64.android.so',
  'libsqlite3.x64.linux.so'
)

# GitHub 加速镜像，地址写法是「镜像前缀 + 完整 GitHub 地址」。它们会失效，
# 换的时候直接改这里。
$mirrors = @(
  'https://ghfast.top/',
  'https://gh-proxy.com/',
  'https://ghproxy.net/'
)

$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root 'third_party\sqlite3'

# 版本和哈希都从 pub 解析出来的那份 sqlite3 包里取。
$packageConfig = Join-Path $root '.dart_tool\package_config.json'
if (-not (Test-Path $packageConfig)) {
  throw '找不到 .dart_tool\package_config.json，先运行 flutter pub get。'
}
$sqlite = (Get-Content $packageConfig -Raw -Encoding UTF8 | ConvertFrom-Json).packages |
  Where-Object { $_.name -eq 'sqlite3' }
if (-not $sqlite) { throw 'package_config.json 里没有 sqlite3 包。' }
$packageRoot = ([Uri]::new([Uri]::new($packageConfig), $sqlite.rootUri)).LocalPath
$hashes = Get-Content (Join-Path $packageRoot 'lib\src\hook\asset_hashes.dart') -Raw -Encoding UTF8
$tag = [regex]::Match($hashes, "releaseTag = '([^']+)'").Groups[1].Value
if (-not $tag) { throw 'asset_hashes.dart 里没找到 releaseTag。' }

New-Item -ItemType Directory -Force $target | Out-Null
foreach ($name in $files) {
  $expected = [regex]::Match($hashes, "'$([regex]::Escape($name))': '([0-9a-f]{64})'").Groups[1].Value
  if (-not $expected) { throw "asset_hashes.dart 里没有 $name 的哈希。" }

  $dest = Join-Path $target $name
  if ((Test-Path $dest) -and (Get-FileHash $dest -Algorithm SHA256).Hash -eq $expected) {
    Write-Host "$name 已是 $tag 的版本"
    continue
  }

  $url = "https://github.com/simolus3/sqlite3.dart/releases/download/$tag/$name"
  $sources = @($url) + @($mirrors | ForEach-Object { $_ + $url })
  $tmp = "$dest.download"
  $done = $false
  foreach ($source in $sources) {
    try {
      Invoke-WebRequest -Uri $source -OutFile $tmp -UseBasicParsing -TimeoutSec 60
    } catch {
      Write-Host "  $source 下载失败：$($_.Exception.Message)"
      continue
    }
    $actual = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -eq $expected) {
      Move-Item -Force $tmp $dest
      Write-Host "$name <- $source"
      $done = $true
      break
    }
    Write-Host "  $source 下载的文件哈希不对（$actual），换下一个源"
  }
  Remove-Item -Force -ErrorAction SilentlyContinue $tmp
  if (-not $done) { throw "$name 所有下载源都失败了。" }
}
