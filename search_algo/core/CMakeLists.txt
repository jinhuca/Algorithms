# se::core — header-only generic search algorithms & data structures (C++20).
cmake_minimum_required(VERSION 3.21)

add_library(se_core INTERFACE)
add_library(se::core ALIAS se_core)

target_include_directories(se_core INTERFACE
    "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_compile_features(se_core INTERFACE cxx_std_20)

# The headers under include/se are GENERATED from the C++20 module sources under
# core/modules (the .ixx, built by search_algo.slnx) via scripts/gen_se_hpp.py --
# the .ixx are the source of truth. Guard against drift: fail the build if any .hpp
# is stale relative to its .ixx. This runs in both the top-level build and the app's
# standalone add_subdirectory(../core), so every consumer is covered. Skipped (with a
# notice) when no Python is available.
find_package(Python3 COMPONENTS Interpreter QUIET)
# find_package only confirms *a* python3 was found on PATH — it does not verify it
# runs. On Windows the "App execution alias" stub (…/WindowsApps/python3.exe)
# satisfies the lookup but is not a real interpreter: it prints a Microsoft Store
# notice and exits nonzero. Probe the resolved interpreter and only register the
# check if it actually runs.
set(_se_python_ok FALSE)
if (Python3_FOUND)
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" -I -c "pass"
        RESULT_VARIABLE _se_py_rc OUTPUT_QUIET ERROR_QUIET)
    if (_se_py_rc EQUAL 0)
        set(_se_python_ok TRUE)
    endif()
endif()
if (_se_python_ok)
    add_custom_target(se_header_sync_check ALL
        COMMAND ${Python3_EXECUTABLE} -I
                "${CMAKE_CURRENT_SOURCE_DIR}/../scripts/gen_se_hpp.py" --check
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/.."
        COMMENT "Checking core/include/se/*.hpp are in sync with their .ixx"
        VERBATIM)
else()
    message(STATUS "No working Python3 interpreter; skipping the se .hpp<->.ixx sync check")
endif()

if (BUILD_TESTING)
    add_subdirectory(tests)
endif()
