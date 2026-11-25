cmake_minimum_required(VERSION 3.21)

# Combinatorics core — header-only generic C++20 algorithms. Skeleton for now: one placeholder
# module (core/modules/combinatorics/placeholder.ixx), the single source of truth, with its
# header-only twin (core/include/cb/placeholder.hpp). The unified generator
# (scripts/gen_hpp.py, see the monorepo README) regenerates the twin from the .ixx.
add_library(cb_core INTERFACE)
add_library(cb::core ALIAS cb_core)
target_include_directories(cb_core INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_compile_features(cb_core INTERFACE cxx_std_20)

# Guard against .ixx/.hpp drift: fail the build if any header twin is stale, via the
# unified monorepo generator (../../scripts/gen_hpp.py). Skipped (with a notice) when no
# working Python3 is available. Mirrors the sa / se / ga cores.
find_package(Python3 COMPONENTS Interpreter QUIET)
set(_cb_python_ok FALSE)
if (Python3_FOUND)
    execute_process(COMMAND "${Python3_EXECUTABLE}" -I -c "pass"
        RESULT_VARIABLE _cb_py_rc OUTPUT_QUIET ERROR_QUIET)
    if (_cb_py_rc EQUAL 0)
        set(_cb_python_ok TRUE)
    endif()
endif()
if (_cb_python_ok)
    add_custom_target(cb_header_sync_check ALL
        COMMAND ${Python3_EXECUTABLE} -I
                "${CMAKE_CURRENT_SOURCE_DIR}/../../scripts/gen_hpp.py"
                --project "${CMAKE_CURRENT_SOURCE_DIR}/.." --ns cb --check
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/.."
        COMMENT "Checking combinatorics_algo/core/include/cb/*.hpp are in sync with their .ixx"
        VERBATIM)
else()
    message(STATUS "No working Python3 interpreter; skipping the cb .hpp<->.ixx sync check")
endif()
