# Algorithms — umbrella build for the whole monorepo.
#
# Aggregates the three algorithm cores (header-only, Qt-free) plus, when
# ALGORITHMS_BUILD_APP is on, the shared UiKit, the three studio module libraries
# and the "Algorithms" umbrella app that hosts them all in one window.
#
#   cmake -S . -B build && cmake --build build                 # cores + their tests
#   cmake -S . -B build-app -G Ninja \                          # + the umbrella app
#     -DCMAKE_PREFIX_PATH=<Qt>/mingw_64 -DALGORITHMS_BUILD_APP=ON
#   cmake --build build-app
#
# Each studio still builds standalone from its own directory (see each README);
# this top-level build is the single entry point that produces the umbrella.
cmake_minimum_required(VERSION 3.21)
project(algorithms LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Tests on by default for a top-level build.
if (CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    enable_testing()
    set(BUILD_TESTING ON CACHE BOOL "Build the core tests")
endif()

# Cores first: header-only INTERFACE libs (sa::core / se::core / ga::core). Adding
# them before the studios satisfies each studio's `if (NOT TARGET <ns>::core)` guard,
# so the studios reuse these single targets instead of re-adding ../core themselves.
add_subdirectory(search_algo/core se_core)
add_subdirectory(sort_algo/core   sa_core)
add_subdirectory(tree_algo/core   tr_core)
add_subdirectory(graph_algo/core  ga_core)
add_subdirectory(foundation_algo/core    fo_core)
add_subdirectory(combinatorics_algo/core cb_core)
add_subdirectory(numerics_algo/core      nu_core)

option(ALGORITHMS_BUILD_APP "Build the Qt/QML Algorithms umbrella app (+ the studio apps)" OFF)
if (ALGORITHMS_BUILD_APP)
    set(CMAKE_AUTOMOC ON)
    find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Quick3D Widgets Multimedia Svg)
    qt_standard_project_setup(REQUIRES 6.5)

    # Shared UiKit first so each studio's `if (NOT TARGET UiKit)` guard skips re-adding
    # it; every studio + the umbrella then link the one shared UiKit / UiKitplugin.
    add_subdirectory(UI_repo ui_kit)

    # Studio module libraries (+ their standalone executables).
    add_subdirectory(search_algo/studio search_studio)
    add_subdirectory(sort_algo/studio   sort_studio)
    add_subdirectory(tree_algo/studio   tree_studio)
    add_subdirectory(graph_algo/studio  graph_studio)
    add_subdirectory(foundation_algo/studio    foundation_studio)
    add_subdirectory(combinatorics_algo/studio combinatorics_studio)
    add_subdirectory(numerics_algo/studio      numerics_studio)

    # The umbrella app that links all three studio modules into one window.
    add_subdirectory(algorithms_studio)
endif()
