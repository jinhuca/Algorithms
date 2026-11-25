# Algorithms umbrella app — one Qt 6 / QML window hosting every studio.
#
# Built as part of the top-level build (../CMakeLists.txt with ALGORITHMS_BUILD_APP=ON),
# which adds the cores, UiKit and the three studio module libraries first. It links all
# three studio modules + their generated QML plugins, so every studio's QML module and
# C++ types register in this one executable's engine.
cmake_minimum_required(VERSION 3.21)

if (NOT TARGET sortstudio OR NOT TARGET searchstudio OR NOT TARGET treestudio OR NOT TARGET graphstudio
        OR NOT TARGET foundationstudio OR NOT TARGET combinatoricsstudio OR NOT TARGET numericsstudio)
    message(FATAL_ERROR
        "algorithms_studio must be built from the top-level Algorithms CMakeLists with "
        "-DALGORITHMS_BUILD_APP=ON (it links every studio module).")
endif()

set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Widgets)
qt_standard_project_setup(REQUIRES 6.5)

qt_policy(SET QTP0004 NEW)

qt_add_executable(algorithms_studio main.cpp)
set_target_properties(algorithms_studio PROPERTIES WIN32_EXECUTABLE TRUE)

# Embed the application icon (Algorithm_Icon.ico, generated from Algorithm_Icon.svg)
# into the Windows executable so it shows in Explorer, the taskbar and Alt-Tab.
if (WIN32)
    enable_language(RC)
    set_source_files_properties(appicon.rc PROPERTIES
        COMPILE_FLAGS "-I\"${CMAKE_CURRENT_SOURCE_DIR}\"")
    target_sources(algorithms_studio PRIVATE appicon.rc)
endif()

qt_add_qml_module(algorithms_studio
    URI Algorithms
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/HomePage.qml
        qml/TitleBar.qml
        qml/ComingSoon.qml
    RESOURCES
        Algorithm_Icon.svg
)

# The three studio modules (+ their static QML plugins) and the shared UiKit. Qt
# modules used only by a studio (Quick3D / Multimedia / Svg) arrive transitively
# through the studios' PUBLIC link interfaces.
target_link_libraries(algorithms_studio PRIVATE
    Qt6::Quick Qt6::QuickControls2 Qt6::Widgets
    sortstudio          sortstudioplugin
    searchstudio        searchstudioplugin
    treestudio          treestudioplugin
    graphstudio         graphstudioplugin
    foundationstudio    foundationstudioplugin
    combinatoricsstudio combinatoricsstudioplugin
    numericsstudio      numericsstudioplugin
    UiKit UiKitplugin)
