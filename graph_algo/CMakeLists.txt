cmake_minimum_required(VERSION 3.21)
project(graph_algo VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Tests on by default for a top-level build; off when consumed as a subproject.
if (CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    enable_testing()
    set(BUILD_TESTING ON CACHE BOOL "Build the core tests")
endif()

add_subdirectory(core)

# The app (Graph Algorithm Studio) is a separate Qt 6 / QML project under studio/;
# opt in explicitly since it needs Qt installed. See studio/README.md. (The option
# name is kept for compatibility with existing build scripts.)
option(GRAPH_ALGO_BUILD_VISUALIZER "Build the Qt/QML Graph Algorithm Studio app" OFF)
if (GRAPH_ALGO_BUILD_VISUALIZER)
    add_subdirectory(studio)
endif()
