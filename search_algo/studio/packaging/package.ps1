# Build, deploy and package Search Algorithm Studio into a Windows installer.
#
#   powershell -ExecutionPolicy Bypass -File packaging\package.ps1 [-Trim] [-Minimal]
#
# Produces build-release\search_algorithm_studio-<version>-setup.exe (and a stable
# build-release\search_algorithm_studio-latest-setup.exe copy).
# Requires: Qt 6.12.0 (MinGW 64-bit) + Inno Setup 6. If Qt lives elsewhere, pass
# -QtRoot (e.g. C:\Qt16) / -QtVer, or individually -QtDir / -MingwDir / -Ninja / -Iscc.

param(
    [string]$QtRoot   = "C:\Qt",        # Qt install root (holds <QtVer>\ and Tools\)
    [string]$QtVer    = "6.12.0",       # Qt version subfolder under the root
    [string]$QtDir    = "",             # default: <QtRoot>\<QtVer>\mingw_64
    [string]$MingwDir = "",             # default: <QtRoot>\Tools\mingw1310_64 (newest mingw*_64 if absent)
    [string]$Ninja    = "",             # default: <QtRoot>\Tools\Ninja\ninja.exe
    [string]$Iscc     = "",             # auto-detected below if empty
    [switch]$Trim,                      # drop clearly-unused files (translations, virtual keyboard)
    [switch]$Minimal,                   # also drop the software-GL fallback + unused Controls styles
    [string]$SignToolCmd = ""           # if set, code-sign the exe + installer (see README)
)
$ErrorActionPreference = "Stop"

# Resolve the Qt kit. Prefer the requested <QtVer>, but if it isn't installed on
# this machine (e.g. only a different Qt version is present, or Qt lives under C:\Qt16), fall back
# to the newest mingw_64 kit found under a known Qt root — so one script builds
# across machines.
$QtRoots = @($QtRoot, "C:\Qt", "C:\Qt16", "D:\Qt", "D:\Qt16") |
    Where-Object { Test-Path $_ } | Select-Object -Unique
if (-not $QtDir) {
    $hit = $QtRoots | Where-Object { Test-Path (Join-Path $_ "$QtVer\mingw_64") } | Select-Object -First 1
    if ($hit) {
        $QtRoot = $hit
    } else {
        $kits = foreach ($r in $QtRoots) {
            Get-ChildItem $r -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName "mingw_64") } |
                ForEach-Object {
                    $v = $null
                    if ([version]::TryParse($_.Name, [ref]$v)) {
                        [pscustomobject]@{ Root = $r; Ver = $_.Name; V = $v }
                    }
                }
        }
        $best = $kits | Sort-Object V -Descending | Select-Object -First 1
        if ($best) {
            Write-Host "    Qt $QtVer not found; using $($best.Ver) under $($best.Root)"
            $QtRoot = $best.Root; $QtVer = $best.Ver
        }
    }
    $QtDir = Join-Path $QtRoot "$QtVer\mingw_64"
}
# Derive the compiler / ninja paths from the chosen root unless passed explicitly.
if (-not $MingwDir) {
    $MingwDir = Join-Path $QtRoot "Tools\mingw1310_64"
    if (-not (Test-Path $MingwDir)) {
        $m = Get-ChildItem (Join-Path $QtRoot "Tools") -Directory -Filter "mingw*_64" -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending | Select-Object -First 1
        if ($m) { $MingwDir = $m.FullName }
    }
}
if (-not $Ninja)    { $Ninja = Join-Path $QtRoot "Tools\Ninja\ninja.exe" }
if (-not (Test-Path $QtDir)) {
    throw "No Qt mingw_64 kit found (looked for '$QtVer' and any version under C:\Qt, C:\Qt16, D:\Qt, D:\Qt16). Pass -QtDir, or -QtRoot/-QtVer."
}

# CMake stores these verbatim in its generated *.cmake files, where backslashes are
# string escapes (e.g. "\Q" is invalid) — so hand CMake forward slashes.
$QtDirFwd    = $QtDir    -replace '\\', '/'
$MingwDirFwd = $MingwDir -replace '\\', '/'
$NinjaFwd    = $Ninja    -replace '\\', '/'

if (-not $Iscc) {
    # Find ISCC.exe under any "Inno Setup <n>" folder (newest major first), so a
    # v6 or v7 install is picked up without -Iscc.
    $Iscc = @("${env:ProgramFiles(x86)}", "${env:ProgramFiles}", "${env:LOCALAPPDATA}\Programs") |
        Where-Object { $_ -and (Test-Path $_) } |
        ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory -Filter "Inno Setup *" -ErrorAction SilentlyContinue } |
        Sort-Object { $n = $_.Name -replace '\D'; if ($n) { [int]$n } else { 0 } } -Descending |
        ForEach-Object { Join-Path $_.FullName "ISCC.exe" } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}
$pkg  = $PSScriptRoot
$root = Split-Path -Parent $pkg          # studio\
$bld  = Join-Path $root "build-release"
$dist = Join-Path $bld  "dist"

Write-Host "==> Configuring + building (Release)"
# studio\CMakeLists.txt pulls in ..\core (and the sibling UiKit) itself when opened standalone.
cmake -S $root -B $bld -G Ninja -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_CXX_COMPILER="$MingwDirFwd/bin/g++.exe" `
    -DCMAKE_RC_COMPILER="$MingwDirFwd/bin/windres.exe" `
    -DCMAKE_MAKE_PROGRAM="$NinjaFwd" `
    -DCMAKE_PREFIX_PATH="$QtDirFwd"
cmake --build $bld

Write-Host "==> Deploying Qt runtime (windeployqt)"
Remove-Item -Recurse -Force $dist -ErrorAction SilentlyContinue
New-Item -ItemType Directory $dist | Out-Null
$distExe = Join-Path $dist "search_algorithm_studio.exe"
Copy-Item (Join-Path $bld "search_algorithm_studio.exe") $dist
# --qmldir points windeployqt at the QML sources so it pulls the right modules
# (QtQuick, Controls). This app is 2D only — no QtQuick3D.
& "$QtDir\bin\windeployqt.exe" --release --compiler-runtime --qmldir "$root\qml" $distExe

function Drop($relPath) { Remove-Item -Recurse -Force (Join-Path $dist $relPath) -ErrorAction SilentlyContinue }

if ($Trim -or $Minimal) {
    Write-Host "==> Trimming unused files"
    Drop "translations"
    Drop "Qt6VirtualKeyboard.dll"
    Drop "qml\QtQuick\VirtualKeyboard"
    Drop "platforminputcontexts\qtvirtualkeyboardplugin.dll"
}
if ($Minimal) {
    Write-Host "==> Minimal: dropping software-GL fallback + unused Controls styles"
    # ~16 MB software OpenGL fallback (only needed where hardware GL is unavailable,
    # e.g. some VMs / Remote Desktop).
    Drop "opengl32sw.dll"
    # The app uses the Fusion style (set in main.cpp); drop the others.
    foreach ($style in @("Material","Universal","Imagine","FluentWinUI3","Windows")) {
        Drop "Qt6QuickControls2$style.dll"
        Drop "Qt6QuickControls2${style}StyleImpl.dll"
        Drop "qml\QtQuick\Controls\$style"
    }
}

if ($SignToolCmd) {
    Write-Host "==> Signing application exe"
    Invoke-Expression "$SignToolCmd `"$distExe`""
}

Write-Host "==> Compiling installer (Inno Setup)"
if (-not $Iscc -or -not (Test-Path $Iscc)) { throw "Inno Setup (ISCC.exe) not found. Install it or pass -Iscc <path>." }
# Reuse the exact version the app shows: CMake's configure wrote build-release\version.h
# (#define SE_APP_VERSION "Major.Minor.Patch.Build"). AppVersion is that display form
# (zero-padded build -> filename + "about"); AppVerInfo strips the zero-padding to the
# plain numeric form Inno requires for the binary VersionInfo resource.
$appVersion = "1.0.0.0"
$verHeader = Join-Path $bld "version.h"
if (Test-Path $verHeader) {
    $m = Select-String -Path $verHeader -Pattern 'SE_APP_VERSION\s+"([^"]+)"'
    if ($m) { $appVersion = $m.Matches[0].Groups[1].Value }
}
$appVerInfo = (($appVersion -split '\.') | ForEach-Object { [int]$_ }) -join '.'
Write-Host "    version $appVersion  (info $appVerInfo)"
$isccArgs = @("/DAppVersion=$appVersion", "/DAppVerInfo=$appVerInfo", (Join-Path $pkg "installer.iss"))
if ($SignToolCmd) { $isccArgs = @("/DSIGN", "/Ssigntool=$SignToolCmd `$f") + $isccArgs }
& $Iscc @isccArgs

Write-Host "==> Writing 'latest' copy"
$built = Get-ChildItem (Join-Path $bld "search_algorithm_studio-*-setup.exe") |
    Where-Object { $_.Name -notlike "*latest*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Copy-Item $built.FullName (Join-Path $bld "search_algorithm_studio-latest-setup.exe") -Force

Write-Host "==> Done. Installers:"
Get-ChildItem (Join-Path $bld "search_algorithm_studio-*-setup.exe") | ForEach-Object {
    "{0,8:N1} MB  {1}" -f ($_.Length/1MB), $_.FullName | Write-Host
}
