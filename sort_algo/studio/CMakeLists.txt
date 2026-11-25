# Sort Algorithm Studio — Qt 6 / QML app. Links the header-only sa::core.
#
# Works both ways:
#   * as part of the top-level build (sort_algo/CMakeLists.txt adds core first),
#   * opened on its own (e.g. in Qt Creator) — it then pulls in ../core itself.
cmake_minimum_required(VERSION 3.21)

# Standalone open: define a project and bring in sa::core from the sibling dir.
if (NOT TARGET sa::core)
    project(sort_algorithm_studio LANGUAGES CXX)
    set(CMAKE_CXX_STANDARD 20)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../core" "${CMAKE_BINARY_DIR}/sa_core")
endif()

set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Widgets Multimedia)
qt_standard_project_setup(REQUIRES 6.5)

# Shared UI module (design tokens + generic controls), consumed from the sibling
# repo D:\exercise\UI_repo — mirrors the sa::core add_subdirectory above. Override
# the location with -DSA_UI_REPO=<path> if it lives elsewhere.
if (NOT TARGET UiKit)
    set(SA_UI_REPO "${CMAKE_CURRENT_SOURCE_DIR}/../../UI_repo"
        CACHE PATH "Path to the shared UiKit UI module")
    add_subdirectory("${SA_UI_REPO}" "${CMAKE_BINARY_DIR}/ui_kit")
endif()

# ---- application version: Major.Minor.Patch.Build --------------------------
set(SA_VERSION "1.1.1")
set(SA_BUILD "0")
find_package(Git QUIET)
if (Git_FOUND)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-list --count HEAD
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        OUTPUT_VARIABLE SA_BUILD OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
endif()
if (SA_BUILD STREQUAL "")
    set(SA_BUILD "0")
endif()
string(LENGTH "${SA_BUILD}" _sa_build_len)       # zero-pad the build to 4 digits
while (_sa_build_len LESS 4)
    set(SA_BUILD "0${SA_BUILD}")
    string(LENGTH "${SA_BUILD}" _sa_build_len)
endwhile()
set(SA_FULL_VERSION "${SA_VERSION}.${SA_BUILD}")
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/version.h.in"
               "${CMAKE_CURRENT_BINARY_DIR}/version.h" @ONLY)

# ---- studio module library: controllers + the QML module -------------------
# The studio content is a static library + QML module (URI SortStudio) so it can be
# linked into either the standalone executable below or the Algorithms umbrella app.
# main.cpp and mem_tracker.cpp (global operator new/delete) stay in the executable
# only — a process can have exactly one global allocator override, so the umbrella
# supplies its own and must not pull in each studio's.
qt_add_library(sortstudio STATIC
    VisualizerController.cpp
    VisualizerController.h
    AnalyzerController.cpp
    AnalyzerController.h
    SystemMonitor.cpp
    SystemMonitor.h
    StabilityController.cpp
    StabilityController.h
    SortAudio.cpp
    SortAudio.h
    RaceController.cpp
    RaceController.h
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_policy(SET QTP0004 NEW)

qt_add_qml_module(sortstudio
    URI SortStudio
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/SortRoot.qml
        qml/Theme.qml
        qml/TitleBar.qml
        qml/HomePage.qml
        qml/VisualizerPage.qml
        qml/SortView.qml
        qml/SortViewDots.qml
        qml/SortViewStrip.qml
        qml/ControlPanel.qml
        qml/RunBar.qml
        qml/StatChip.qml
        qml/SectionHeader.qml
        qml/LiveUtilization.qml
        qml/Pseudocode.qml
        qml/AnalyzerPage.qml
        qml/ScalingChart.qml
        qml/KnowledgePage.qml
        qml/KnowledgeContent.qml
        qml/StabilityPage.qml
        qml/RacePage.qml
    RESOURCES
        sa_logo.png
        sa_logo.svg
)

# PUBLIC so whatever links this library (the standalone exe or the umbrella app)
# transitively gets the Qt modules, sa::core and the shared UiKit module + plugin.
target_link_libraries(sortstudio
    PUBLIC Qt6::Quick Qt6::QuickControls2 Qt6::Widgets Qt6::Multimedia sa::core UiKit UiKitplugin)

# The studio library reads the generated version.h (SA_APP_VERSION) to expose the
# build-stamped version to QML (VisualizerController::appVersion).
target_include_directories(sortstudio PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

# psapi: GetProcessMemoryInfo (process working set); pdh: GPU-engine utilisation.
if (WIN32)
    target_link_libraries(sortstudio PUBLIC psapi pdh)
endif()

# ---- standalone executable -------------------------------------------------
qt_add_executable(sort_algorithm_studio main.cpp mem_tracker.cpp)

# GUI-subsystem app (no console window).
set_target_properties(sort_algorithm_studio PROPERTIES WIN32_EXECUTABLE TRUE)

# Generated version.h (configure_file above) lives in the build dir.
target_include_directories(sort_algorithm_studio PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

# Embed the application icon (sa_logo) into the Windows executable.
if (WIN32)
    enable_language(RC)
    set_source_files_properties(appicon.rc PROPERTIES
        COMPILE_FLAGS "-I\"${CMAKE_CURRENT_SOURCE_DIR}\"")
    target_sources(sort_algorithm_studio PRIVATE appicon.rc)
endif()

# Link the studio module + its generated QML plugin (static-plugin registration).
target_link_libraries(sort_algorithm_studio PRIVATE sortstudio sortstudioplugin)

# IDE convenience: surface the core's generated header twins (../core/include/sa/**/*.hpp)
# under this module in Qt Creator so they're navigable alongside the studio. They are
# header-only (already consumed via sa::core's include path); listing them as target
# sources does NOT compile them — it only makes them show in the project tree.
file(GLOB_RECURSE _sa_core_twins CONFIGURE_DEPENDS
     "${CMAKE_CURRENT_SOURCE_DIR}/../core/include/sa/*.hpp")
if (_sa_core_twins)
    target_sources(sortstudio PRIVATE ${_sa_core_twins})
endif()
