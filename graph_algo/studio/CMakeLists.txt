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
set(GA_VERSION "1.3.2")
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

qt_add_executable(graph_algorithm_studio
    main.cpp
    VisualizerController.cpp
    VisualizerController_io.cpp
    VisualizerController_run.cpp
    VisualizerController.h
    AnalyzerController.cpp
    AnalyzerController.h
    SystemMonitor.cpp
    SystemMonitor.h
    mem_tracker.cpp
    GraphInstanceTable.cpp
    GraphInstanceTable.h
)

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

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_policy(SET QTP0004 NEW)

qt_add_qml_module(graph_algorithm_studio
    URI GraphVis
    VERSION 1.0
    QML_FILES
        qml/Main.qml
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

target_link_libraries(graph_algorithm_studio PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Quick3D Qt6::Widgets ga::core UiKit UiKitplugin)

# psapi: GetProcessMemoryInfo (process working set); pdh: GPU-engine utilisation.
if (WIN32)
    target_link_libraries(graph_algorithm_studio PRIVATE psapi pdh)
endif()
