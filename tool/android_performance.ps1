[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("reset", "capture")]
    [string]$Action,

    [string]$DeviceId,
    [string]$PackageName = "com.yarizm.yunchuang",
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\performance-results")
)

$ErrorActionPreference = "Stop"

function Resolve-AdbPath {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -ne $adbCommand) {
        return $adbCommand.Source
    }

    $candidates = @()
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA `
            "Android\Sdk\platform-tools\adb.exe"
    }
    if ($env:ANDROID_HOME) {
        $candidates += Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "adb was not found. Install Android platform-tools or add adb to PATH."
}

function Get-ConnectedDeviceIds {
    param([string]$AdbPath)

    $lines = & $AdbPath devices
    if ($LASTEXITCODE -ne 0) {
        throw "adb devices failed with exit code $LASTEXITCODE."
    }

    return @(
        $lines |
            Select-Object -Skip 1 |
            ForEach-Object {
                if ($_ -match "^(?<id>\S+)\s+device$") {
                    $Matches.id
                }
            }
    )
}

function Invoke-DeviceAdb {
    param(
        [string]$AdbPath,
        [string]$TargetDevice,
        [string[]]$Arguments
    )

    $output = & $AdbPath -s $TargetDevice @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb command failed with exit code $LASTEXITCODE."
    }
    return $output
}

$adb = Resolve-AdbPath
$connectedDevices = @(Get-ConnectedDeviceIds -AdbPath $adb)
if ($connectedDevices.Count -eq 0) {
    throw "No authorized Android device is connected."
}

if (-not $DeviceId) {
    if ($connectedDevices.Count -gt 1) {
        throw "Multiple Android devices are connected. Pass -DeviceId explicitly."
    }
    $DeviceId = $connectedDevices[0]
} elseif ($DeviceId -notin $connectedDevices) {
    throw "Device '$DeviceId' is not connected or authorized."
}

$packagePath = Invoke-DeviceAdb -AdbPath $adb -TargetDevice $DeviceId `
    -Arguments @("shell", "pm", "path", $PackageName)
if (-not ($packagePath -match "^package:")) {
    throw "Package '$PackageName' is not installed on device '$DeviceId'."
}

if ($Action -eq "reset") {
    Invoke-DeviceAdb -AdbPath $adb -TargetDevice $DeviceId `
        -Arguments @("shell", "dumpsys", "gfxinfo", $PackageName, "reset") |
        Out-Null
    Write-Host "Frame statistics reset for $PackageName on $DeviceId."
    Write-Host "Run one fixed scenario from PERFORMANCE.md, then use -Action capture."
    exit 0
}

$resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path $resolvedOutputDirectory `
    "gfxinfo-$DeviceId-$timestamp.txt"

$model = (
    Invoke-DeviceAdb -AdbPath $adb -TargetDevice $DeviceId `
        -Arguments @("shell", "getprop", "ro.product.model")
).Trim()
$androidVersion = (
    Invoke-DeviceAdb -AdbPath $adb -TargetDevice $DeviceId `
        -Arguments @("shell", "getprop", "ro.build.version.release")
).Trim()
$refreshRate = (
    Invoke-DeviceAdb -AdbPath $adb -TargetDevice $DeviceId `
        -Arguments @("shell", "dumpsys", "display") |
        Select-String -Pattern "mRefreshRate|refreshRate" |
        Select-Object -First 1
).Line
$gfxInfo = Invoke-DeviceAdb -AdbPath $adb -TargetDevice $DeviceId `
    -Arguments @("shell", "dumpsys", "gfxinfo", $PackageName, "framestats")

@(
    "# Yunchuang Android performance report"
    "captured_at=$(Get-Date -Format o)"
    "device_id=$DeviceId"
    "model=$model"
    "android=$androidVersion"
    "package=$PackageName"
    "display=$refreshRate"
    ""
    $gfxInfo
) | Set-Content -LiteralPath $reportPath -Encoding utf8

Write-Host "Performance report written to $reportPath"
