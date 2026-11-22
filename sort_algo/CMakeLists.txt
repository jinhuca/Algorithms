cmake_minimum_required(VERSION 3.21)
project(sort_algo VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Tests on by default for a top-level build; off when consumed as a subproject.
if (CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    enable_testing()
    set(BUILD_TESTING ON CACHE BOOL "Build the core tests")
endif()

add_subdirectory(core)

# The app (Sort Algorithm Studio) is a separate Qt 6 / QML project under studio/;
# opt in explicitly since it needs Qt installed. See studio/README.md.
option(SORT_ALGO_BUILD_APP "Build the Qt/QML Sort Algorithm Studio app" OFF)
if (SORT_ALGO_BUILD_APP)
    add_subdirectory(studio)
endif()
