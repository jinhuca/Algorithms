# studio — Search Algorithm Studio (Qt 6 / QML app)

The desktop front-end for the `se::core` search library. Opt-in build (needs Qt 6 and the
shared [UiKit](../../UI_repo) module). See the top-level [ARCHITECTURE.md](../ARCHITECTURE.md)
for the full design.

## Layout

- `main.cpp` — `QApplication`, splash, loads the `SearchStudio` QML module.
- `VisualizerController.{h,cpp}` — builds a sorted array + target, records the chosen
  search's step trace, and replays it (forward/back/seek) into a per-bar `BarModel`,
  tracking the sliding lo/hi window and discarded regions.
- `AnalyzerController.{h,cpp}` — threaded benchmark sweep (deterministic probe counts +
  timed ns/search) streamed into `AnalyzerResultsModel`; CSV export.
- `qml/` — `Main` (shell + page router), `TitleBar`, `HomePage`, `VisualizerPage`
  (+ `ArrayView` / `ControlPanel` / `RunBar` / `Pseudocode` / `StatChip`), `AnalyzerPage`
  (+ `ScalingChart`), `KnowledgePage` (+ `KnowledgeContent`), and the app `Theme` singleton
  (delegates generic tokens to `UiKit.UiPalette`).
- `search_logo.svg` — app icon (window + splash; rendered via Qt's SVG image plugin);
  `search_logo.ico` (multi-size, generated from it) is embedded in the exe (`appicon.rc`).

## Build

```sh
cmake -S .. -B ../build-app -G Ninja -DCMAKE_PREFIX_PATH=<Qt>/mingw_64 -DSEARCH_ALGO_BUILD_APP=ON
cmake --build ../build-app
../build-app/studio/search_algorithm_studio.exe
```

Or open `studio/CMakeLists.txt` directly in Qt Creator — it pulls in `../core` and the
UiKit sibling itself. Override the UiKit location with `-DSE_UI_REPO=<path>`.

## Packaging (Windows installer)

`packaging/package.ps1` builds Release, deploys the Qt runtime with `windeployqt`, and
compiles a per-user Windows installer with Inno Setup — in one step:

```powershell
powershell -ExecutionPolicy Bypass -File packaging\package.ps1 -Trim
```

Produces `studio\build-release\search_algorithm_studio-<version>-setup.exe` (and a stable
`…-latest-setup.exe`). Requires Qt 6.12 (MinGW 64-bit) + Inno Setup 6; override tool
locations via `-QtDir` / `-MingwDir` / `-Ninja` / `-Iscc`. `-Minimal` additionally drops
the software-GL fallback and unused Controls styles for a smaller installer; `-SignToolCmd`
code-signs the exe + installer. The installer definition is `packaging/installer.iss`; it
ships `packaging/THIRD-PARTY-NOTICES.txt` (Qt LGPLv3 + MinGW runtime notices). The icon is
`search_logo.ico` (a multi-size 16–256 px icon generated from `search_logo.svg`, with
uncompressed **BMP** frames — PNG-compressed icon frames can break GNU `windres` and fail
to render in the shell), embedded in the exe via `appicon.rc` (CMake adds an `OBJECT_DEPENDS`
so changing the `.ico` rebuilds it) and used as the setup.exe icon (`SetupIconFile`).

## Scope

Mirrors Sort Algorithm Studio's Home + Visualizer + Analyzer + Knowledge. The sort-only
Race / Stability workspaces, the live system monitor and per-step sound are omitted — they
don't map onto a single-target search.
