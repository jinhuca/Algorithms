cmake_minimum_required(VERSION 3.21)

# Standalone open: define a project and bring in cb::core from the sibling dir.
if (NOT TARGET cb::core)
    project(combinatorics_algo_studio LANGUAGES CXX)
    set(CMAKE_CXX_STANDARD 20)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../core" "${CMAKE_BINARY_DIR}/cb_core")
endif()

set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Widgets)
qt_standard_project_setup(REQUIRES 6.5)

if (NOT TARGET UiKit)
    set(CB_UI_REPO "${CMAKE_CURRENT_SOURCE_DIR}/../../UI_repo"
        CACHE PATH "Path to the shared UiKit UI module")
    add_subdirectory("${CB_UI_REPO}" "${CMAKE_BINARY_DIR}/ui_kit")
endif()

qt_policy(SET QTP0004 NEW)

# Studio module library + QML module (URI CombinatoricsStudio), linkable into the standalone exe
# below or the Algorithms umbrella app.
qt_add_library(combinatoricsstudio STATIC
    PlaceholderController.cpp
    PlaceholderController.h
)
qt_add_qml_module(combinatoricsstudio
    URI CombinatoricsStudio
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/CombinatoricsRoot.qml
    RESOURCES
        cb_logo.svg
)
target_link_libraries(combinatoricsstudio
    PUBLIC Qt6::Quick Qt6::QuickControls2 Qt6::Widgets cb::core UiKit UiKitplugin)

# Standalone executable.
qt_add_executable(combinatorics_algorithm_studio main.cpp)
set_target_properties(combinatorics_algorithm_studio PROPERTIES WIN32_EXECUTABLE TRUE)
target_link_libraries(combinatorics_algorithm_studio PRIVATE combinatoricsstudio combinatoricsstudioplugin)

# IDE convenience: surface the core's generated header twins (../core/include/cb/**/*.hpp)
# under this module in Qt Creator so they're navigable alongside the studio. They are
# header-only (already consumed via cb::core's include path); listing them as target
# sources does NOT compile them — it only makes them show in the project tree.
file(GLOB_RECURSE _cb_core_twins CONFIGURE_DEPENDS
     "${CMAKE_CURRENT_SOURCE_DIR}/../core/include/cb/*.hpp")
if (_cb_core_twins)
    target_sources(combinatoricsstudio PRIVATE ${_cb_core_twins})
endif()
