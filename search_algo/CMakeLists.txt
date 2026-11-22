cmake_minimum_required(VERSION 3.21)
project(search_algo VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Tests on by default for a top-level build; off when consumed as a subproject.
if (CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    enable_testing()
    set(BUILD_TESTING ON CACHE BOOL "Build the core tests")
endif()

add_subdirectory(core)

# The app (Search Algorithm Studio) is a separate Qt 6 / QML project under studio/
# (phase 2); opt in explicitly since it needs Qt installed. See ARCHITECTURE.md.
option(SEARCH_ALGO_BUILD_APP "Build the Qt/QML Search Algorithm Studio app" OFF)
if (SEARCH_ALGO_BUILD_APP)
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/studio/CMakeLists.txt")
        add_subdirectory(studio)
    else()
        message(FATAL_ERROR
            "SEARCH_ALGO_BUILD_APP=ON but studio/ has not been built yet (phase 2). "
            "The portable se::core library + tests build without it.")
    endif()
endif()
