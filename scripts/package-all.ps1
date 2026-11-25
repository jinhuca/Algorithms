# Build + package every app in the monorepo in one pass: the Algorithms umbrella app
# AND each individual studio (Search / Sort / Graph) installer. Shared Qt / Inno
# settings are resolved once and forwarded to the per-studio packagers.
#
#   powershell -ExecutionPolicy Bypass -File scripts\package-all.ps1 [-Trim] [-Minimal]
#
# Produces:
#   algorithms_studio\build-release\algorithms-<ver>-setup.exe        (umbrella)
#   <studio>\build-release\<studio>_algorithm_studio-<ver>-setup.exe  (each studio)
#
# Requires Qt 6 (MinGW 64-bit) + Inno Setup 6/7. Pass -QtRoot / -QtVer (or -QtDir /
# -MingwDir / -Ninja / -Iscc) if they aren't auto-detected.
#
# NOTE: this orchestrator reuses each studio's proven packaging\package.ps1 verbatim;
# the umbrella deploy below mirrors that same flow for the merged app.
param(
    [string]$QtRoot   = "C:\Qt",
    [string]$QtVer    = "6.12.0",
    [string]$QtDir    = "",
    [string]$MingwDir = "",
    [string]$Ninja    = "",
    [string]$Iscc     = "",
    [switch]$Trim,
    [switch]$Minimal,
    [switch]$SkipStudios,          # build + package only the umbrella
    [switch]$SkipUmbrella,         # build + package only the individual studios
    [string]$SignToolCmd = ""
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot      # monorepo root

# ---- resolve the Qt kit (same logic as each studio's package.ps1) ----
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
                    if ([version]::TryParse($_.Name, [ref]$v)) { [pscustomobject]@{ Root = $r; Ver = $_.Name; V = $v } }
                }
        }
        $best = $kits | Sort-Object V -Descending | Select-Object -First 1
        if ($best) { Write-Host "    Qt $QtVer not found; using $($best.Ver) under $($best.Root)"; $QtRoot = $best.Root; $QtVer = $best.Ver }
    }
    $QtDir = Join-Path $QtRoot "$QtVer\mingw_64"
}
if (-not $MingwDir) {
    $MingwDir = Join-Path $QtRoot "Tools\mingw1310_64"
    if (-not (Test-Path $MingwDir)) {
        $m = Get-ChildItem (Join-Path $QtRoot "Tools") -Directory -Filter "mingw*_64" -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending | Select-Object -First 1
        if ($m) { $MingwDir = $m.FullName }
    }
}
if (-not $Ninja) { $Ninja = Join-Path $QtRoot "Tools\Ninja\ninja.exe" }
if (-not (Test-Path $QtDir)) { throw "No Qt mingw_64 kit found. Pass -QtDir, or -QtRoot/-QtVer." }

if (-not $Iscc) {
    $Iscc = @("${env:ProgramFiles(x86)}", "${env:ProgramFiles}", "${env:LOCALAPPDATA}\Programs") |
        Where-Object { $_ -and (Test-Path $_) } |
        ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory -Filter "Inno Setup *" -ErrorAction SilentlyContinue } |
        Sort-Object { $n = $_.Name -replace '\D'; if ($n) { [int]$n } else { 0 } } -Descending |
        ForEach-Object { Join-Path $_.FullName "ISCC.exe" } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}

$QtDirFwd    = $QtDir    -replace '\\', '/'
$MingwDirFwd = $MingwDir -replace '\\', '/'
$NinjaFwd    = $Ninja    -replace '\\', '/'

# ---- umbrella app ----
if (-not $SkipUmbrella) {
    Write-Host "`n===== Algorithms umbrella ====="
    $uroot = Join-Path $repo "algorithms_studio"
    $ubld  = Join-Path $uroot "build-release"
    $udist = Join-Path $ubld  "dist"

    Write-Host "==> Configuring + building the umbrella (Release)"
    # Built from the monorepo root with ALGORITHMS_BUILD_APP so every studio module links in.
    cmake -S $repo -B $ubld -G Ninja -DCMAKE_BUILD_TYPE=Release -DALGORITHMS_BUILD_APP=ON `
        -DCMAKE_CXX_COMPILER="$MingwDirFwd/bin/g++.exe" `
        -DCMAKE_RC_COMPILER="$MingwDirFwd/bin/windres.exe" `
        -DCMAKE_MAKE_PROGRAM="$NinjaFwd" `
        -DCMAKE_PREFIX_PATH="$QtDirFwd"
    cmake --build $ubld --target algorithms_studio

    $exe = Get-ChildItem -Path $ubld -Recurse -Filter "algorithms_studio.exe" |
           Select-Object -First 1
    if (-not $exe) { throw "built algorithms_studio.exe not found under $ubld" }

    Write-Host "==> Deploying Qt runtime (windeployqt)"
    Remove-Item -Recurse -Force $udist -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $udist | Out-Null
    $distExe = Join-Path $udist "algorithms_studio.exe"
    Copy-Item $exe.FullName $udist
    # Scan the whole repo's QML so every studio's imports (incl. graph's QtQuick3D) are
    # deployed, not just the umbrella's own.
    & "$QtDir\bin\windeployqt.exe" --release --compiler-runtime --qmldir "$repo" $distExe

    function Drop($rel) { Remove-Item -Recurse -Force (Join-Path $udist $rel) -ErrorAction SilentlyContinue }
    if ($Trim -or $Minimal) {
        Drop "translations"; Drop "Qt6VirtualKeyboard.dll"
        Drop "qml\QtQuick\VirtualKeyboard"; Drop "platforminputcontexts\qtvirtualkeyboardplugin.dll"
    }
    if ($Minimal) {
        Drop "opengl32sw.dll"
        foreach ($s in @("Material","Universal","Imagine","FluentWinUI3","Windows")) {
            Drop "Qt6QuickControls2$s.dll"; Drop "Qt6QuickControls2${s}StyleImpl.dll"; Drop "qml\QtQuick\Controls\$s"
        }
    }
    if ($SignToolCmd) { Invoke-Expression "$SignToolCmd `"$distExe`"" }

    if ($Iscc -and (Test-Path $Iscc)) {
        Write-Host "==> Compiling umbrella installer (Inno Setup)"
        $ver = "1.0.0.0"                                   # umbrella version (see main.cpp)
        $isccArgs = @("/DAppVersion=$ver", "/DAppVerInfo=$ver", (Join-Path $uroot "packaging\installer.iss"))
        if ($SignToolCmd) { $isccArgs = @("/DSIGN", "/Ssigntool=$SignToolCmd `$f") + $isccArgs }
        & $Iscc @isccArgs
    } else {
        Write-Warning "Inno Setup not found; umbrella deployed to '$udist' but no installer built. Pass -Iscc <path>."
    }
}

# ---- individual studios (reuse each studio's own proven packager) ----
if (-not $SkipStudios) {
    $fwd = @{ QtRoot = $QtRoot; QtVer = $QtVer; QtDir = $QtDir; MingwDir = $MingwDir; Ninja = $Ninja }
    if ($Iscc) { $fwd.Iscc = $Iscc }
    if ($Trim) { $fwd.Trim = $true }
    if ($Minimal) { $fwd.Minimal = $true }
    if ($SignToolCmd) { $fwd.SignToolCmd = $SignToolCmd }

    foreach ($studio in @("search_algo", "sort_algo", "graph_algo")) {
        $ps = Join-Path $repo "$studio\studio\packaging\package.ps1"
        if (-not (Test-Path $ps)) { Write-Warning "no packager for $studio ($ps); skipping"; continue }
        Write-Host "`n===== $studio ====="
        & $ps @fwd
    }
}

Write-Host "`n==> package-all done."
