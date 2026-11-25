cmake_minimum_required(VERSION 3.21)

# Standalone open: define a project and bring in fo::core from the sibling dir.
if (NOT TARGET fo::core)
    project(foundation_algo_studio LANGUAGES CXX)
    set(CMAKE_CXX_STANDARD 20)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../core" "${CMAKE_BINARY_DIR}/fo_core")
endif()

set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Widgets)
qt_standard_project_setup(REQUIRES 6.5)

if (NOT TARGET UiKit)
    set(FO_UI_REPO "${CMAKE_CURRENT_SOURCE_DIR}/../../UI_repo"
        CACHE PATH "Path to the shared UiKit UI module")
    add_subdirectory("${FO_UI_REPO}" "${CMAKE_BINARY_DIR}/ui_kit")
endif()

qt_policy(SET QTP0004 NEW)

# Studio module library + QML module (URI FoundationStudio), linkable into the standalone exe
# below or the Algorithms umbrella app.
qt_add_library(foundationstudio STATIC
    PlaceholderController.cpp
    PlaceholderController.h
)
qt_add_qml_module(foundationstudio
    URI FoundationStudio
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/FoundationRoot.qml
    RESOURCES
        fo_logo.svg
)
target_link_libraries(foundationstudio
    PUBLIC Qt6::Quick Qt6::QuickControls2 Qt6::Widgets fo::core UiKit UiKitplugin)

# Standalone executable.
qt_add_executable(foundation_algorithm_studio main.cpp)
set_target_properties(foundation_algorithm_studio PROPERTIES WIN32_EXECUTABLE TRUE)
target_link_libraries(foundation_algorithm_studio PRIVATE foundationstudio foundationstudioplugin)

# IDE convenience: surface the core's generated header twins (../core/include/fo/**/*.hpp)
# under this module in Qt Creator so they're navigable alongside the studio. They are
# header-only (already consumed via fo::core's include path); listing them as target
# sources does NOT compile them — it only makes them show in the project tree.
file(GLOB_RECURSE _fo_core_twins CONFIGURE_DEPENDS
     "${CMAKE_CURRENT_SOURCE_DIR}/../core/include/fo/*.hpp")
if (_fo_core_twins)
    target_sources(foundationstudio PRIVATE ${_fo_core_twins})
endif()
