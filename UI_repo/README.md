# UiKit — shared UI module

A standalone Qt 6 / QML module providing the **design system** shared across app
repositories (e.g. `graph_algo`'s graph_visualizer, and others). It holds:

- **Design tokens** (singletons, populated from Figma):
  - `UiPalette` — colour tokens (light / dark; `dark` is the single input the app binds)
  - `Typography` — font family + size scale
  - `Metrics` — spacing, radii, control sizing, border widths
- **Generic controls** styled from the tokens:
  - `UiButton`, `UiToggleButton`, `UiComboBox`, `UiMessagePopup`

Module URI: **`UiKit`**. App repos keep their own app logic and domain-specific UI
(e.g. graph node/edge/algorithm-state colours) and delegate the generic tokens to
this module.

## Use from an app (CMake)

Consumed as a sibling via `add_subdirectory` (no install step):

```cmake
if (NOT TARGET UiKit)
    add_subdirectory("<path>/UI_repo" "${CMAKE_BINARY_DIR}/ui_kit")
endif()
target_link_libraries(<app> PRIVATE UiKit UiKitplugin)
```

Then in QML: `import UiKit` and reference `UiPalette`, `Typography`, `Metrics`,
`UiButton`, etc. Bind the palette's dark flag from the app:

```qml
Binding { target: UiPalette; property: "dark"; value: myDarkModeFlag }
```

## Build standalone

```
cmake -S . -B build -G Ninja -DCMAKE_PREFIX_PATH=<Qt>/mingw_64
cmake --build build
```

## Figma → tokens

The token singletons (`UiPalette` / `Typography` / `Metrics`) are the single place
to drop Figma-exported colour/type/spacing values. A Figma-export → token
generator can be added later.
