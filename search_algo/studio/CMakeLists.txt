# Search Algorithm Studio — Qt 6 / QML app. Links the header-only se::core.
#
# Works both ways:
#   * as part of the top-level build (search_algo/CMakeLists.txt adds core first),
#   * opened on its own (e.g. in Qt Creator) — it then pulls in ../core itself.
cmake_minimum_required(VERSION 3.21)

# Standalone open: define a project and bring in se::core from the sibling dir.
if (NOT TARGET se::core)
    project(search_algorithm_studio LANGUAGES CXX)
    set(CMAKE_CXX_STANDARD 20)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../core" "${CMAKE_BINARY_DIR}/se_core")
endif()

set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Widgets Svg)
qt_standard_project_setup(REQUIRES 6.5)

# Shared UI module (design tokens + generic controls), consumed from the sibling repo
# D:\exercise\UI_repo — mirrors the se::core add_subdirectory above. Override the
# location with -DSE_UI_REPO=<path> if it lives elsewhere.
if (NOT TARGET UiKit)
    set(SE_UI_REPO "${CMAKE_CURRENT_SOURCE_DIR}/../../UI_repo"
        CACHE PATH "Path to the shared UiKit UI module")
    add_subdirectory("${SE_UI_REPO}" "${CMAKE_BINARY_DIR}/ui_kit")
endif()

# ---- application version: Major.Minor.Patch.Build --------------------------
set(SE_VERSION "1.1.0")
set(SE_BUILD "0")
find_package(Git QUIET)
if (Git_FOUND)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-list --count HEAD
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        OUTPUT_VARIABLE SE_BUILD OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
endif()
if (SE_BUILD STREQUAL "")
    set(SE_BUILD "0")
endif()
string(LENGTH "${SE_BUILD}" _se_build_len)       # zero-pad the build to 4 digits
while (_se_build_len LESS 4)
    set(SE_BUILD "0${SE_BUILD}")
    string(LENGTH "${SE_BUILD}" _se_build_len)
endwhile()
set(SE_FULL_VERSION "${SE_VERSION}.${SE_BUILD}")
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/version.h.in"
               "${CMAKE_CURRENT_BINARY_DIR}/version.h" @ONLY)

# ---- studio module library: controllers + the QML module -------------------
# The studio content is a static library + QML module (URI SearchStudio) so it can be
# linked into either the standalone executable below or the Algorithms umbrella app.
# main.cpp stays in the executable only.
qt_add_library(searchstudio STATIC
    VisualizerController.cpp
    VisualizerController.h
    AnalyzerController.cpp
    AnalyzerController.h
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_policy(SET QTP0004 NEW)

qt_add_qml_module(searchstudio
    URI SearchStudio
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/SearchRoot.qml
        qml/Theme.qml
        qml/TitleBar.qml
        qml/HomePage.qml
        qml/VisualizerPage.qml
        qml/ArrayView.qml
        qml/ControlPanel.qml
        qml/RunBar.qml
        qml/StatChip.qml
        qml/SectionHeader.qml
        qml/Pseudocode.qml
        qml/AnalyzerPage.qml
        qml/ScalingChart.qml
        qml/KnowledgePage.qml
        qml/KnowledgeContent.qml
    RESOURCES
        search_logo.svg
)

# PUBLIC so whatever links this library (the standalone exe or the umbrella app)
# transitively gets the Qt modules, se::core and the shared UiKit module + plugin.
target_link_libraries(searchstudio
    PUBLIC Qt6::Quick Qt6::QuickControls2 Qt6::Widgets Qt6::Svg se::core UiKit UiKitplugin)

# Lets the studio library read the generated version.h (SE_APP_VERSION) for
# VisualizerController::appVersion (shown in the umbrella title bar).
target_include_directories(searchstudio PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

# ---- standalone executable -------------------------------------------------
qt_add_executable(search_algorithm_studio main.cpp)

# GUI-subsystem app (no console window).
set_target_properties(search_algorithm_studio PROPERTIES WIN32_EXECUTABLE TRUE)

# Generated version.h (configure_file above) lives in the build dir.
target_include_directories(search_algorithm_studio PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

# Embed the application icon (search_logo) into the Windows executable.
if (WIN32)
    enable_language(RC)
    set_source_files_properties(appicon.rc PROPERTIES
        COMPILE_FLAGS "-I\"${CMAKE_CURRENT_SOURCE_DIR}\""
        OBJECT_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/search_logo.ico")
    target_sources(search_algorithm_studio PRIVATE appicon.rc)
endif()

# Link the studio module + its generated QML plugin (static-plugin registration).
target_link_libraries(search_algorithm_studio PRIVATE searchstudio searchstudioplugin)

# IDE convenience: surface the core's generated header twins (../core/include/se/**/*.hpp)
# under this module in Qt Creator so they're navigable alongside the studio. They are
# header-only (already consumed via se::core's include path); listing them as target
# sources does NOT compile them — it only makes them show in the project tree.
file(GLOB_RECURSE _se_core_twins CONFIGURE_DEPENDS
     "${CMAKE_CURRENT_SOURCE_DIR}/../core/include/se/*.hpp")
if (_se_core_twins)
    target_sources(searchstudio PRIVATE ${_se_core_twins})
endif()
