# Graph Algorithm Studio — Qt 6 / QML app. Links the header-only ga::core.
#
# Works both ways:
#   * as part of the top-level build (graph_algo/CMakeLists.txt adds core first),
#   * opened on its own (e.g. in Qt Creator) — it then pulls in ../core itself.
cmake_minimum_required(VERSION 3.21)

# Standalone open: define a project and bring in ga::core from the sibling dir.
if (NOT TARGET ga::core)
    project(graph_algorithm_studio LANGUAGES CXX)
    set(CMAKE_CXX_STANDARD 20)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../core" "${CMAKE_BINARY_DIR}/ga_core")
endif()

set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Quick3D Widgets)
qt_standard_project_setup(REQUIRES 6.5)

# Shared UI module (design tokens + generic controls), consumed from the sibling
# repo D:\exercise\UI_repo — mirrors the ga::core add_subdirectory above. Override
# the location with -DGA_UI_REPO=<path> if it lives elsewhere.
if (NOT TARGET UiKit)
    set(GA_UI_REPO "${CMAKE_CURRENT_SOURCE_DIR}/../../UI_repo"
        CACHE PATH "Path to the shared UiKit UI module")
    add_subdirectory("${GA_UI_REPO}" "${CMAKE_BINARY_DIR}/ui_kit")
endif()

# ---- application version: Major.Minor.Patch.Build --------------------------
# Major.Minor.Patch is bumped by hand (keep in sync with packaging/installer.iss
# AppVersion). Build is an auto number = the git commit count, zero-padded to 4
# digits, (re)computed at CMake configure time. version.h.in -> version.h feeds
# main.cpp, which publishes it as Qt.application.version for the title bar.
set(GA_VERSION "1.4.2")
set(GA_BUILD "0")
find_package(Git QUIET)
if (Git_FOUND)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-list --count HEAD
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        OUTPUT_VARIABLE GA_BUILD OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
endif()
if (GA_BUILD STREQUAL "")
    set(GA_BUILD "0")
endif()
string(LENGTH "${GA_BUILD}" _ga_build_len)       # zero-pad the build to 4 digits
while (_ga_build_len LESS 4)
    set(GA_BUILD "0${GA_BUILD}")
    string(LENGTH "${GA_BUILD}" _ga_build_len)
endwhile()
set(GA_FULL_VERSION "${GA_VERSION}.${GA_BUILD}")
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/version.h.in"
               "${CMAKE_CURRENT_BINARY_DIR}/version.h" @ONLY)

# ---- studio module library: controllers + the QML module -------------------
# The studio content is a static library + QML module (URI GraphVis) so it can be
# linked into either the standalone executable below or the Algorithms umbrella app.
# main.cpp and mem_tracker.cpp (global operator new/delete) stay in the executable
# only — a process can have exactly one global allocator override, so the umbrella
# supplies its own and must not pull in each studio's.
qt_add_library(graphstudio STATIC
    VisualizerController.cpp
    VisualizerController_io.cpp
    VisualizerController_run.cpp
    VisualizerController.h
    AnalyzerController.cpp
    AnalyzerController.h
    SystemMonitor.cpp
    SystemMonitor.h
    GraphInstanceTable.cpp
    GraphInstanceTable.h
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_policy(SET QTP0004 NEW)

qt_add_qml_module(graphstudio
    URI GraphVis
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/GraphRoot.qml
        qml/Theme.qml
        qml/TitleBar.qml
        qml/HomePage.qml
        qml/AnalyzerPage.qml
        qml/ScalingChart.qml
        qml/KnowledgePage.qml
        qml/KnowledgeContent.qml
        qml/LiveUtilization.qml
        qml/GraphView2D.qml
        qml/GraphView3D.qml
        qml/Controls2D.qml
        qml/Controls3D.qml
        qml/SectionHeader.qml
        qml/Grip.qml
        qml/GraphViewBase.qml
        qml/Dialogs.qml
        qml/RunBar.qml
        qml/ControlPanel.qml
        qml/BusyOverlay.qml
        qml/Overlay2D.qml
        qml/Overlay3D.qml
        qml/ToolDivider.qml
    RESOURCES
        ga_logo.png
        graph_logo.svg
)

# Present the .qml files under a "Qmls" node in IDEs that honour source_group
# (Visual Studio / Qt Creator), with "controls" and "views" sub-nodes, instead of
# lumping them under "Source Files". IDE-only grouping; nothing moves on disk.
source_group("Qmls" FILES          # entry point + shared singleton
    qml/Main.qml
    qml/GraphRoot.qml
    qml/Theme.qml
)
source_group("Qmls\\controls" FILES   # window chrome, panel, run bar, dialogs, shared widgets
    qml/TitleBar.qml
    qml/HomePage.qml
    qml/AnalyzerPage.qml
    qml/ScalingChart.qml
    qml/KnowledgePage.qml
    qml/KnowledgeContent.qml
    qml/ControlPanel.qml
    qml/Controls2D.qml
    qml/Controls3D.qml
    qml/RunBar.qml
    qml/Dialogs.qml
    qml/BusyOverlay.qml
    qml/SectionHeader.qml
    qml/Grip.qml
    qml/ToolDivider.qml
)
source_group("Qmls\\views" FILES      # the 2D/3D canvas views + their overlays
    qml/GraphViewBase.qml
    qml/GraphView2D.qml
    qml/GraphView3D.qml
    qml/Overlay2D.qml
    qml/Overlay3D.qml
)

# PUBLIC so whatever links this library (the standalone exe or the umbrella app)
# transitively gets the Qt modules, ga::core and the shared UiKit module + plugin.
target_link_libraries(graphstudio PUBLIC Qt6::Quick Qt6::QuickControls2 Qt6::Quick3D Qt6::Widgets ga::core UiKit UiKitplugin)

# Lets the studio library read the generated version.h (GA_APP_VERSION) for
# VisualizerController::appVersion (shown in the umbrella title bar).
target_include_directories(graphstudio PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

# psapi: GetProcessMemoryInfo (process working set); pdh: GPU-engine utilisation.
if (WIN32)
    target_link_libraries(graphstudio PUBLIC psapi pdh)
endif()

# ---- standalone executable -------------------------------------------------
qt_add_executable(graph_algorithm_studio main.cpp mem_tracker.cpp)

# GUI-subsystem app (no console window).
set_target_properties(graph_algorithm_studio PROPERTIES WIN32_EXECUTABLE TRUE)

# Generated version.h (configure_file above) lives in the build dir.
target_include_directories(graph_algorithm_studio PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

# Embed the application icon (ga_logo) into the Windows executable, so it shows
# in Explorer, the taskbar and Alt-Tab. windres resolves ga_logo.ico relative to
# the .rc file; add the source dir to its search path to be safe.
if (WIN32)
    enable_language(RC)
    set_source_files_properties(appicon.rc PROPERTIES
        COMPILE_FLAGS "-I\"${CMAKE_CURRENT_SOURCE_DIR}\"")
    target_sources(graph_algorithm_studio PRIVATE appicon.rc)
endif()

# Link the studio module + its generated QML plugin (static-plugin registration).
target_link_libraries(graph_algorithm_studio PRIVATE graphstudio graphstudioplugin)

# IDE convenience: surface the core's generated header twins (../core/include/ga/**/*.hpp)
# under this module in Qt Creator so they're navigable alongside the studio. They are
# header-only (already consumed via ga::core's include path); listing them as target
# sources does NOT compile them — it only makes them show in the project tree.
file(GLOB_RECURSE _ga_core_twins CONFIGURE_DEPENDS
     "${CMAKE_CURRENT_SOURCE_DIR}/../core/include/ga/*.hpp")
if (_ga_core_twins)
    target_sources(graphstudio PRIVATE ${_ga_core_twins})
endif()
